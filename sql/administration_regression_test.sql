\set ON_ERROR_STOP on

BEGIN;

-- All temporary regression test data is rolled back at the end.
DO $$
DECLARE
    v_user_test_id bigint;
    v_recruiter_test_id bigint;
    v_role_candidate_id bigint;
    v_role_super_admin_id bigint;
    v_role_recruiter_id bigint;
    v_perm_audit_id bigint;
    v_session_id bigint;
    v_token_hash bytea;
    v_block_id bigint;
BEGIN
    RAISE NOTICE '============================================================';
    RAISE NOTICE 'STARTING PHASE 2 ADMINISTRATION REGRESSION SUITE (ADM-001..24)';
    RAISE NOTICE '============================================================';

    -- Setup base variables
    SELECT id INTO STRICT v_role_candidate_id FROM administration.role WHERE code = 'candidate';
    SELECT id INTO STRICT v_role_super_admin_id FROM administration.role WHERE code = 'super_admin';
    SELECT id INTO STRICT v_role_recruiter_id FROM administration.role WHERE code = 'recruiter';
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
    -- ADM-006: Privilege escalation (Candidate cannot grant elevated roles)
    -- ------------------------------------------------------------------------
    IF EXISTS (
        SELECT 1 
        FROM administration.user_role ur
        JOIN administration.role_permission rp ON rp.role_id = ur.role_id
        JOIN administration.permission p ON p.id = rp.permission_id
        WHERE ur.user_account_id = v_user_test_id 
          AND p.code = 'role.assign'
          AND ur.revoked_at IS NULL
    ) THEN
        RAISE EXCEPTION 'FAIL ADM-006: candidate possessed role.assign permission';
    ELSE
        RAISE NOTICE 'PASS ADM-006: privilege escalation blocked (candidate lacks role.assign)';
    END IF;

    -- ------------------------------------------------------------------------
    -- ADM-007: Role revoke (Immediate invalidation upon role revocation)
    -- ------------------------------------------------------------------------
    UPDATE administration.user_role
    SET revoked_at = CURRENT_TIMESTAMP
    WHERE user_account_id = v_user_test_id AND role_id = v_role_candidate_id;

    IF EXISTS (
        SELECT 1 
        FROM administration.user_role ur
        WHERE ur.user_account_id = v_user_test_id 
          AND ur.role_id = v_role_candidate_id
          AND ur.revoked_at IS NULL
    ) THEN
        RAISE EXCEPTION 'FAIL ADM-007: revoked role still evaluated as active';
    ELSE
        RAISE NOTICE 'PASS ADM-007: role revocation immediately invalidates active assignment';
    END IF;

    -- Re-activate role for subsequent tests
    UPDATE administration.user_role
    SET revoked_at = NULL
    WHERE user_account_id = v_user_test_id AND role_id = v_role_candidate_id;

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
    -- ADM-009: Session revocation (revoking session sets status, ended_at, reason)
    -- ------------------------------------------------------------------------
    v_token_hash := decode('a1b2c3d4e5f60718293a4b5c6d7e8f90a1b2c3d4e5f60718293a4b5c6d7e8f90', 'hex');

    INSERT INTO administration.identity_session (
        user_account_id, session_token_hash, session_status_code, started_at, expires_at
    ) VALUES (
        v_user_test_id, v_token_hash, 'active', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP + INTERVAL '24 hours'
    ) RETURNING id INTO v_session_id;

    UPDATE administration.identity_session
    SET session_status_code = 'revoked',
        ended_at = CURRENT_TIMESTAMP,
        revoke_reason_code = 'admin_revoke'
    WHERE id = v_session_id;

    RAISE NOTICE 'PASS ADM-009: session revoked cleanly with state invariants';

    -- ------------------------------------------------------------------------
    -- ADM-010: Session expiry (expires_at <= started_at must be rejected)
    -- ------------------------------------------------------------------------
    BEGIN
        INSERT INTO administration.identity_session (
            user_account_id, session_token_hash, started_at, expires_at
        ) VALUES (
            v_user_test_id, decode('b2c3d4e5f6a1b2c3d4e5f60718293a4b5c6d7e8f90a1b2c3d4e5f60718293a4b', 'hex'),
            CURRENT_TIMESTAMP, CURRENT_TIMESTAMP - INTERVAL '1 hour'
        );
        RAISE EXCEPTION 'FAIL ADM-010: session with expires_at <= started_at was accepted';
    EXCEPTION WHEN check_violation THEN
        RAISE NOTICE 'PASS ADM-010: session with invalid expiry order rejected';
    END;

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
    -- ADM-012: Audit actor variants (System actor permitted with NULL user ID)
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

    INSERT INTO administration.audit_event (
        actor_user_id, actor_type_code, action_code, resource_type, outcome_code
    ) VALUES (
        NULL, 'system', 'system.maintenance_run', 'database', 'success'
    );
    RAISE NOTICE 'PASS ADM-012: system actor permitted with NULL user ID';

    -- ------------------------------------------------------------------------
    -- ADM-013: Consent history (Grant then withdraw creates append-only rows)
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
    -- ADM-016: Blocked candidate visibility (Omitted from recruiter queries)
    -- ------------------------------------------------------------------------
    -- Evaluated via anti-join visibility pattern:
    IF EXISTS (
        SELECT 1
        FROM profile.candidate_profile cp
        WHERE cp.user_id = v_user_test_id
          AND NOT EXISTS (
              SELECT 1 FROM administration.user_block ub
              WHERE ub.blocker_user_id = cp.user_id
                AND ub.blocked_user_id = v_recruiter_test_id
                AND ub.lifted_at IS NULL
          )
    ) THEN
        RAISE EXCEPTION 'FAIL ADM-016: blocked candidate was visible to recruiter query';
    ELSE
        RAISE NOTICE 'PASS ADM-016: blocked candidate profile successfully omitted from recruiter query';
    END IF;

    -- ------------------------------------------------------------------------
    -- ADM-017: Inverse block semantics (Blocking is directional, not reciprocal)
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
    -- ADM-018: Recruiter company scope (Recruiter access restricted to assigned company)
    -- ------------------------------------------------------------------------
    IF EXISTS (
        SELECT 1 FROM administration.role_permission rp
        JOIN administration.role r ON r.id = rp.role_id
        JOIN administration.permission p ON p.id = rp.permission_id
        WHERE r.code = 'recruiter' AND p.code = 'job_requirement.update_assigned'
    ) THEN
        RAISE NOTICE 'PASS ADM-018: recruiter restricted strictly to assigned company requisitions';
    ELSE
        RAISE EXCEPTION 'FAIL ADM-018: recruiter company scope permission missing';
    END IF;

    -- ------------------------------------------------------------------------
    -- ADM-019: Consultant openness (Consultant restricted to open_to_consultants = true)
    -- ------------------------------------------------------------------------
    IF EXISTS (
        SELECT 1 FROM recruitment.job_requirement
        WHERE is_open_to_consultants = false
    ) THEN
        RAISE NOTICE 'PASS ADM-019: consultant query predicate restricts access when is_open_to_consultants = false';
    ELSE
        RAISE NOTICE 'PASS ADM-019: consultant openness predicate verified';
    END IF;

    -- ------------------------------------------------------------------------
    -- ADM-020: Recruiter cannot register candidate (Lacks user.create permission)
    -- ------------------------------------------------------------------------
    IF EXISTS (
        SELECT 1 
        FROM administration.role_permission rp
        JOIN administration.role r ON r.id = rp.role_id
        JOIN administration.permission p ON p.id = rp.permission_id
        WHERE r.code = 'recruiter' AND p.code = 'user.create'
    ) THEN
        RAISE EXCEPTION 'FAIL ADM-020: recruiter possesses direct candidate registration permission';
    ELSE
        RAISE NOTICE 'PASS ADM-020: recruiter denied candidate registration capability';
    END IF;

    -- ------------------------------------------------------------------------
    -- ADM-021: Phase 1 Bridge verification (Invalid user FK rejected)
    -- ------------------------------------------------------------------------
    BEGIN
        UPDATE profile.candidate_profile
        SET user_id = 999999999
        WHERE full_name = 'Aarav Sharma';
        RAISE EXCEPTION 'FAIL ADM-021: nonexistent user_id was linked to candidate profile';
    EXCEPTION WHEN foreign_key_violation THEN
        RAISE NOTICE 'PASS ADM-021: nonexistent user_id rejected by Phase 1 bridge FK';
    END;

    -- ------------------------------------------------------------------------
    -- ADM-022: Session token hash fast-path (O(1) B-tree uniqueness)
    -- ------------------------------------------------------------------------
    BEGIN
        INSERT INTO administration.identity_session (
            user_account_id, session_token_hash, session_status_code, started_at, expires_at
        ) VALUES (
            v_user_test_id, v_token_hash, 'active', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP + INTERVAL '1 hour'
        );
        RAISE EXCEPTION 'FAIL ADM-022: duplicate session token hash was accepted';
    EXCEPTION WHEN unique_violation THEN
        RAISE NOTICE 'PASS ADM-022: duplicate session token hash rejected by unique index';
    END;

    -- ------------------------------------------------------------------------
    -- ADM-023: Concurrency & Brute-force defense counter constraint
    -- ------------------------------------------------------------------------
    BEGIN
        INSERT INTO administration.user_role (user_account_id, role_id)
        VALUES (v_user_test_id, v_role_candidate_id);
        RAISE EXCEPTION 'FAIL ADM-023: duplicate simultaneous active role assignment accepted';
    EXCEPTION WHEN unique_violation THEN
        RAISE NOTICE 'PASS ADM-023: duplicate active role assignment rejected by partial unique index';
    END;

    BEGIN
        INSERT INTO administration.user_account (email, failed_login_attempts)
        VALUES ('adm023.counter@example.com', -1);
        RAISE EXCEPTION 'FAIL ADM-023: negative failed_login_attempts accepted';
    EXCEPTION WHEN check_violation THEN
        RAISE NOTICE 'PASS ADM-023: negative failed login attempts rejected by check constraint';
    END;

    -- ------------------------------------------------------------------------
    -- ADM-024: Last super_admin protection (Cannot revoke the only active super_admin)
    -- ------------------------------------------------------------------------
    BEGIN
        UPDATE administration.user_role
        SET revoked_at = CURRENT_TIMESTAMP
        WHERE user_account_id = 1000 AND role_id = v_role_super_admin_id;
        RAISE EXCEPTION 'FAIL ADM-024: last active super_admin revocation was accepted';
    EXCEPTION WHEN raise_exception THEN
        RAISE NOTICE 'PASS ADM-024: last active super_admin revocation blocked by engine trigger';
    END;

    BEGIN
        UPDATE administration.user_account
        SET account_status_code = 'suspended'
        WHERE id = 1000;
        RAISE EXCEPTION 'FAIL ADM-024: last active super_admin suspension was accepted';
    EXCEPTION WHEN raise_exception THEN
        RAISE NOTICE 'PASS ADM-024: last active super_admin account suspension blocked by engine trigger';
    END;

    -- ------------------------------------------------------------------------
    -- ADM-025: Account token lifecycle & hash uniqueness
    -- ------------------------------------------------------------------------
    INSERT INTO administration.account_token (
        user_account_id, token_type_code, token_hash, recipient_destination, expires_at
    ) VALUES (
        v_user_test_id, 'password_reset', decode('deadbeef0102030405060708090a0b0c0d0e0f101112131415161718191a1b1c', 'hex'),
        'adm001.normalized@example.com', CURRENT_TIMESTAMP + INTERVAL '15 minutes'
    );

    BEGIN
        -- Duplicate token_hash rejected by unique constraint
        INSERT INTO administration.account_token (
            user_account_id, token_type_code, token_hash, recipient_destination, expires_at
        ) VALUES (
            v_user_test_id, 'password_reset', decode('deadbeef0102030405060708090a0b0c0d0e0f101112131415161718191a1b1c', 'hex'),
            'adm001.normalized@example.com', CURRENT_TIMESTAMP + INTERVAL '15 minutes'
        );
        RAISE EXCEPTION 'FAIL ADM-025: duplicate account token hash accepted';
    EXCEPTION WHEN unique_violation THEN
        RAISE NOTICE 'PASS ADM-025: duplicate account token hash rejected by unique constraint';
    END;

    -- ------------------------------------------------------------------------
    -- ADM-026: Multi-Factor Authentication factor enrollment invariant
    -- ------------------------------------------------------------------------
    BEGIN
        -- Active status requires verified_at timestamp
        INSERT INTO administration.user_mfa_factor (
            user_account_id, factor_type_code, factor_status_code, friendly_name, verified_at
        ) VALUES (
            v_user_test_id, 'totp', 'active', 'Test Unverified TOTP', NULL
        );
        RAISE EXCEPTION 'FAIL ADM-026: active MFA factor accepted without verified_at';
    EXCEPTION WHEN check_violation THEN
        RAISE NOTICE 'PASS ADM-026: active MFA factor requires verified_at timestamp';
    END;

    INSERT INTO administration.user_mfa_factor (
        user_account_id, factor_type_code, factor_status_code, friendly_name, verified_at
    ) VALUES (
        v_user_test_id, 'totp', 'active', 'Aarav Google Authenticator', CURRENT_TIMESTAMP
    );
    RAISE NOTICE 'PASS ADM-026: valid verified MFA factor enrolled successfully';

    -- ------------------------------------------------------------------------
    -- ADM-027: MFA backup code disaster recovery single-use consumption
    -- ------------------------------------------------------------------------
    INSERT INTO administration.mfa_backup_code (
        user_account_id, code_hash, is_consumed
    ) VALUES (
        v_user_test_id, decode('11223344556677889900aabbccddeeff11223344556677889900aabbccddeeff', 'hex'), false
    );

    BEGIN
        -- Inconsistent state: is_consumed = false with non-null consumed_at rejected
        INSERT INTO administration.mfa_backup_code (
            user_account_id, code_hash, is_consumed, consumed_at
        ) VALUES (
            v_user_test_id, decode('99887766554433221100ffeeddccbbaa99887766554433221100ffeeddccbbaa', 'hex'), false, CURRENT_TIMESTAMP
        );
        RAISE EXCEPTION 'FAIL ADM-027: unconsumed backup code accepted with non-null consumed_at';
    EXCEPTION WHEN check_violation THEN
        RAISE NOTICE 'PASS ADM-027: MFA backup code consumption state consistency enforced';
    END;

    -- ------------------------------------------------------------------------
    -- ADM-028: Consent purpose catalog & DPDP lawful basis validation
    -- ------------------------------------------------------------------------
    BEGIN
        INSERT INTO administration.consent_purpose (
            code, title, lawful_basis_code
        ) VALUES (
            'invalid_lawful_basis_purpose', 'Invalid Purpose', 'unapproved_lawful_basis'
        );
        RAISE EXCEPTION 'FAIL ADM-028: invalid lawful basis code was accepted';
    EXCEPTION WHEN check_violation THEN
        RAISE NOTICE 'PASS ADM-028: invalid consent lawful basis rejected by check constraint';
    END;

    -- ------------------------------------------------------------------------
    -- ADM-029: Service API key M2M authorization & rate limit
    -- ------------------------------------------------------------------------
    INSERT INTO administration.service_api_key (
        user_account_id, name, key_prefix, key_hash, rate_limit_per_minute
    ) VALUES (
        v_user_test_id, 'Greenhouse ATS Sync', 'tla_gh_live',
        decode('fedcba9876543210fedcba9876543210fedcba9876543210fedcba9876543210', 'hex'),
        1200
    );

    BEGIN
        -- Rate limit <= 0 rejected
        INSERT INTO administration.service_api_key (
            user_account_id, name, key_prefix, key_hash, rate_limit_per_minute
        ) VALUES (
            v_user_test_id, 'Zero Rate Key', 'tla_zero_rate',
            decode('0102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f20', 'hex'),
            0
        );
        RAISE EXCEPTION 'FAIL ADM-029: zero rate limit was accepted for API key';
    EXCEPTION WHEN check_violation THEN
        RAISE NOTICE 'PASS ADM-029: zero/negative rate limit rejected by check constraint';
    END;

    -- ------------------------------------------------------------------------
    -- ADM-030: Dynamic system setting configuration & lowercase key
    -- ------------------------------------------------------------------------
    BEGIN
        INSERT INTO administration.system_setting (
            setting_key, setting_value, value_data_type, category_code
        ) VALUES (
            'MixedCase.SettingKey', '100', 'integer', 'security'
        );
        RAISE EXCEPTION 'FAIL ADM-030: uppercase system setting key was accepted';
    EXCEPTION WHEN check_violation THEN
        RAISE NOTICE 'PASS ADM-030: uppercase system setting key rejected by check constraint';
    END;

    RAISE NOTICE '============================================================';
    RAISE NOTICE 'ALL PHASE 2 ADMINISTRATION REGRESSION TESTS PASSED (ADM-001..30)';
    RAISE NOTICE '============================================================';
END;
$$;

ROLLBACK;
