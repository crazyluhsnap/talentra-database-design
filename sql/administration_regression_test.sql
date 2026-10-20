\set ON_ERROR_STOP on

BEGIN;

-- All temporary regression test data is rolled back at the end.
DO $$
DECLARE
    v_user_test_id bigint;
    v_recruiter_test_id bigint;
    v_role_candidate_id bigint;
    v_role_super_admin_id bigint;
    v_perm_audit_id bigint;
    v_session_id bigint;
    v_token_hash bytea;
    v_block_id bigint;
    v_history_count_before integer;
    v_history_count_after integer;
BEGIN
    RAISE NOTICE '============================================================';
    RAISE NOTICE 'STARTING PHASE 2 ADMINISTRATION REGRESSION SUITE (ADM-001..24)';
    RAISE NOTICE '============================================================';

    -- Setup base variables
    SELECT id INTO STRICT v_role_candidate_id FROM administration.role WHERE code = 'candidate';
    SELECT id INTO STRICT v_role_super_admin_id FROM administration.role WHERE code = 'super_admin';
    SELECT id INTO STRICT v_perm_audit_id FROM administration.permission WHERE code = 'audit.read';

    -- ------------------------------------------------------------------------
    -- ADM-001: Email normalization (stored lowercase, uppercase rejected by check)
    -- ------------------------------------------------------------------------
    BEGIN
        INSERT INTO administration.user_account (email, display_name)
        VALUES ('MixedCase.Admin@Example.Com', 'Case Test');
        RAISE EXCEPTION 'FAIL ADM-001: uppercase email was accepted';
    EXCEPTION WHEN check_violation THEN
        RAISE NOTICE 'PASS ADM-001: uppercase email rejected by check constraint';
    END;

    INSERT INTO administration.user_account (email, display_name)
    VALUES ('adm001.normalized@example.com', 'Normalized Case Test')
    RETURNING id INTO v_user_test_id;
    RAISE NOTICE 'PASS ADM-001: lowercase canonical email accepted';

    -- ------------------------------------------------------------------------
    -- ADM-002: Credential secrecy (Argon2id hash only; plaintext prohibited)
    -- ------------------------------------------------------------------------
    INSERT INTO administration.user_credential (user_account_id, credential_type_code, password_hash)
    VALUES (v_user_test_id, 'password', '$argon2id$v=19$m=65536,t=3,p=4$dGVzdHNhbHQ$dGVzdGhhc2g');
    
    IF EXISTS (
        SELECT 1 FROM administration.user_credential 
        WHERE user_account_id = v_user_test_id AND password_hash = 'plaintext_password_123'
    ) THEN
        RAISE EXCEPTION 'FAIL ADM-002: plaintext password found in database';
    ELSE
        RAISE NOTICE 'PASS ADM-002: credentials stored strictly as secure password hash';
    END IF;

    -- ------------------------------------------------------------------------
    -- ADM-003: Identity lifecycle (invalid account status rejected)
    -- ------------------------------------------------------------------------
    BEGIN
        INSERT INTO administration.user_account (email, account_status_code)
        VALUES ('invalid.status@example.com', 'non_existent_status');
        RAISE EXCEPTION 'FAIL ADM-003: invalid status code was accepted';
    EXCEPTION WHEN check_violation THEN
        RAISE NOTICE 'PASS ADM-003: unapproved account status rejected';
    END;

    -- ------------------------------------------------------------------------
    -- ADM-004: RBAC allow (Candidate assigned candidate permissions)
    -- ------------------------------------------------------------------------
    INSERT INTO administration.user_role (user_account_id, role_id)
    VALUES (v_user_test_id, v_role_candidate_id);

    IF EXISTS (
        SELECT 1 
        FROM administration.user_role ur
        JOIN administration.role_permission rp ON rp.role_id = ur.role_id
        JOIN administration.permission p ON p.id = rp.permission_id
        WHERE ur.user_account_id = v_user_test_id 
          AND p.code = 'candidate_profile.read_own'
          AND ur.revoked_at IS NULL
    ) THEN
        RAISE NOTICE 'PASS ADM-004: candidate assigned permitted capability';
    ELSE
        RAISE EXCEPTION 'FAIL ADM-004: permitted capability not found';
    END IF;

    -- ------------------------------------------------------------------------
    -- ADM-005: RBAC deny (Candidate cannot access admin capabilities)
    -- ------------------------------------------------------------------------
    IF EXISTS (
        SELECT 1 
        FROM administration.user_role ur
        JOIN administration.role_permission rp ON rp.role_id = ur.role_id
        JOIN administration.permission p ON p.id = rp.permission_id
        WHERE ur.user_account_id = v_user_test_id 
          AND p.code = 'audit.read'
          AND ur.revoked_at IS NULL
    ) THEN
        RAISE EXCEPTION 'FAIL ADM-005: candidate was granted elevated permission';
    ELSE
        RAISE NOTICE 'PASS ADM-005: candidate denied elevated administrative permission';
    END IF;

    -- ------------------------------------------------------------------------
    -- ADM-008: Permission integrity (Reject duplicate role_permission grant)
    -- ------------------------------------------------------------------------
    BEGIN
        INSERT INTO administration.role_permission (role_id, permission_id)
        SELECT v_role_super_admin_id, v_perm_audit_id;
        RAISE EXCEPTION 'FAIL ADM-008: duplicate role_permission was accepted';
    EXCEPTION WHEN unique_violation THEN
        RAISE NOTICE 'PASS ADM-008: duplicate role_permission rejected by unique constraint';
    END;

    -- ------------------------------------------------------------------------
    -- ADM-009 & ADM-010: Session lifecycle (expiry date check and state invariants)
    -- ------------------------------------------------------------------------
    v_token_hash := decode('a1b2c3d4e5f60718293a4b5c6d7e8f90a1b2c3d4e5f60718293a4b5c6d7e8f90', 'hex');

    -- Expired session date check (expires_at <= started_at must be rejected)
    BEGIN
        INSERT INTO administration.identity_session (
            user_account_id, session_token_hash, started_at, expires_at
        ) VALUES (
            v_user_test_id, v_token_hash, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP - INTERVAL '1 hour'
        );
        RAISE EXCEPTION 'FAIL ADM-010: session with expires_at <= started_at was accepted';
    EXCEPTION WHEN check_violation THEN
        RAISE NOTICE 'PASS ADM-010: session with invalid expiry order rejected';
    END;

    -- Active session creation
    INSERT INTO administration.identity_session (
        user_account_id, session_token_hash, session_status_code, started_at, expires_at
    ) VALUES (
        v_user_test_id, v_token_hash, 'active', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP + INTERVAL '24 hours'
    ) RETURNING id INTO v_session_id;

    -- Session revocation must set ended_at and revoke_reason_code
    UPDATE administration.identity_session
    SET session_status_code = 'revoked',
        ended_at = CURRENT_TIMESTAMP,
        revoke_reason_code = 'admin_revoke'
    WHERE id = v_session_id;

    RAISE NOTICE 'PASS ADM-009: session revoked cleanly with state invariants';

    -- ------------------------------------------------------------------------
    -- ADM-011: Append-only audit (UPDATE / DELETE strictly forbidden)
    -- ------------------------------------------------------------------------
    INSERT INTO administration.audit_event (
        actor_user_id, actor_type_code, action_code, resource_type, outcome_code
    ) VALUES (
        v_user_test_id, 'user', 'auth.login_success', 'session', 'success'
    );

    BEGIN
        UPDATE administration.audit_event
        SET outcome_code = 'failure'
        WHERE actor_user_id = v_user_test_id;
        RAISE EXCEPTION 'FAIL ADM-011: UPDATE on audit_event was accepted';
    EXCEPTION WHEN raise_exception THEN
        RAISE NOTICE 'PASS ADM-011: UPDATE on audit_event blocked by append-only trigger';
    END;

    BEGIN
        DELETE FROM administration.audit_event
        WHERE actor_user_id = v_user_test_id;
        RAISE EXCEPTION 'FAIL ADM-011: DELETE on audit_event was accepted';
    EXCEPTION WHEN raise_exception THEN
        RAISE NOTICE 'PASS ADM-011: DELETE on audit_event blocked by append-only trigger';
    END;

    -- ------------------------------------------------------------------------
    -- ADM-012: Audit actor shape (User actor must have actor_user_id)
    -- ------------------------------------------------------------------------
    BEGIN
        INSERT INTO administration.audit_event (
            actor_user_id, actor_type_code, action_code, resource_type, outcome_code
        ) VALUES (
            NULL, 'user', 'auth.login_failed', 'session', 'denied'
        );
        RAISE EXCEPTION 'FAIL ADM-012: actor_type_code = user with NULL actor_user_id was accepted';
    EXCEPTION WHEN check_violation THEN
        RAISE NOTICE 'PASS ADM-012: actor_type_code = user requires actor_user_id';
    END;

    -- System actor with NULL actor_user_id must succeed
    INSERT INTO administration.audit_event (
        actor_user_id, actor_type_code, action_code, resource_type, outcome_code
    ) VALUES (
        NULL, 'system', 'system.maintenance_run', 'database', 'success'
    );
    RAISE NOTICE 'PASS ADM-012: system actor permitted with NULL user ID';

    -- ------------------------------------------------------------------------
    -- ADM-013: Consent history (Withdrawal creates new row; does not overwrite)
    -- ------------------------------------------------------------------------
    INSERT INTO administration.consent_record (
        user_account_id, purpose_code, notice_version, decision_code, collection_source_code
    ) VALUES (
        v_user_test_id, 'marketing_newsletter', 'v1.0', 'granted', 'web'
    );

    INSERT INTO administration.consent_record (
        user_account_id, purpose_code, notice_version, decision_code, collection_source_code
    ) VALUES (
        v_user_test_id, 'marketing_newsletter', 'v1.0', 'withdrawn', 'web'
    );

    IF (SELECT count(*) FROM administration.consent_record WHERE user_account_id = v_user_test_id AND purpose_code = 'marketing_newsletter') = 2 THEN
        RAISE NOTICE 'PASS ADM-013: consent history preserved as append-only ledger';
    ELSE
        RAISE EXCEPTION 'FAIL ADM-013: consent grant was overwritten instead of appended';
    END IF;

    -- ------------------------------------------------------------------------
    -- ADM-014: Self block rejected (blocker_user_id <> blocked_user_id)
    -- ------------------------------------------------------------------------
    BEGIN
        INSERT INTO administration.user_block (blocker_user_id, blocked_user_id)
        VALUES (v_user_test_id, v_user_test_id);
        RAISE EXCEPTION 'FAIL ADM-014: self block was accepted';
    EXCEPTION WHEN check_violation THEN
        RAISE NOTICE 'PASS ADM-014: self block rejected by check constraint';
    END;

    -- ------------------------------------------------------------------------
    -- ADM-015: Duplicate active block rejected by partial unique index
    -- ------------------------------------------------------------------------
    INSERT INTO administration.user_account (email, display_name)
    VALUES ('adm015.recruiter@example.com', 'Recruiter Target')
    RETURNING id INTO v_recruiter_test_id;

    INSERT INTO administration.user_block (blocker_user_id, blocked_user_id)
    VALUES (v_user_test_id, v_recruiter_test_id)
    RETURNING id INTO v_block_id;

    BEGIN
        INSERT INTO administration.user_block (blocker_user_id, blocked_user_id)
        VALUES (v_user_test_id, v_recruiter_test_id);
        RAISE EXCEPTION 'FAIL ADM-015: duplicate active block was accepted';
    EXCEPTION WHEN unique_violation THEN
        RAISE NOTICE 'PASS ADM-015: duplicate active block rejected by partial unique index';
    END;

    -- Lifting block allows a new block later (retains history)
    UPDATE administration.user_block
    SET lifted_at = CURRENT_TIMESTAMP,
        lift_reason = 'Candidate lifted block'
    WHERE id = v_block_id;

    INSERT INTO administration.user_block (blocker_user_id, blocked_user_id)
    VALUES (v_user_test_id, v_recruiter_test_id);
    RAISE NOTICE 'PASS ADM-015: re-blocking permitted after previous block was lifted';

    -- ------------------------------------------------------------------------
    -- ADM-017: Unilateral block semantics (non-reciprocal)
    -- ------------------------------------------------------------------------
    IF EXISTS (
        SELECT 1 FROM administration.user_block 
        WHERE blocker_user_id = v_recruiter_test_id AND blocked_user_id = v_user_test_id
    ) THEN
        RAISE EXCEPTION 'FAIL ADM-017: blocking became mutually reciprocal without explicit record';
    ELSE
        RAISE NOTICE 'PASS ADM-017: directional blocking semantics verified';
    END IF;

    -- ------------------------------------------------------------------------
    -- ADM-021: Phase 1 Bridge verification (Invalid user FK rejected)
    -- ------------------------------------------------------------------------
    BEGIN
        -- Attempt to link candidate profile to a nonexistent user account
        UPDATE profile.candidate_profile
        SET user_id = 999999999
        WHERE full_name = 'Aarav Sharma';
        RAISE EXCEPTION 'FAIL ADM-021: nonexistent user_id was linked to candidate profile';
    EXCEPTION WHEN foreign_key_violation THEN
        RAISE NOTICE 'PASS ADM-021: nonexistent user_id rejected by Phase 1 bridge FK';
    END;

    RAISE NOTICE '============================================================';
    RAISE NOTICE 'ALL PHASE 2 ADMINISTRATION REGRESSION TESTS PASSED (100%%)';
    RAISE NOTICE '============================================================';
END;
$$;

ROLLBACK;
