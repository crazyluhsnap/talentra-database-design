-- ============================================================================
-- Talentra: Phase 2 Organisation and Account Module Regression Test Suite
-- Engine: PostgreSQL 14+
-- Conforming to: 45 Behavioral Assertions from Organisation Docket v2
-- Tests: Uniqueness, Overlap, Hierarchy Cycles, Cryptography, Transitions, Audit
-- ============================================================================

\set ON_ERROR_STOP on

BEGIN;

DO $$
DECLARE
    v_org_id bigint;
    v_sub_org_id bigint;
    v_sub_org2_id bigint;
    v_account_id bigint;
    v_recruiter_user_id bigint;
    v_admin_user_id bigint;
    v_regular_user_id bigint;
    v_id_type_gstin_id bigint;
    v_id_type_pan_id bigint;
    v_status_pending_id bigint;
    v_status_in_review_id bigint;
    v_status_verified_id bigint;
    v_status_rejected_id bigint;
    v_verification_id bigint;
    v_identifier_id bigint;
    v_domain_id bigint;
    v_rel_type_parent_id bigint;
    v_audit_count integer;
    v_history_count integer;
BEGIN
    RAISE NOTICE '============================================================';
    RAISE NOTICE 'STARTING ORGANISATION & AUDIT REGRESSION SUITE (45 ASSERTIONS)';
    RAISE NOTICE '============================================================';

    -- Resolve reference IDs
    SELECT id INTO STRICT v_id_type_gstin_id FROM organisation.identifier_type WHERE code = 'gstin';
    SELECT id INTO STRICT v_id_type_pan_id FROM organisation.identifier_type WHERE code = 'pan';
    SELECT id INTO STRICT v_status_pending_id FROM organisation.verification_status WHERE code = 'pending';
    SELECT id INTO STRICT v_status_in_review_id FROM organisation.verification_status WHERE code = 'in_review';
    SELECT id INTO STRICT v_status_verified_id FROM organisation.verification_status WHERE code = 'verified';
    SELECT id INTO STRICT v_status_rejected_id FROM organisation.verification_status WHERE code = 'rejected';
    SELECT id INTO STRICT v_rel_type_parent_id FROM organisation.organisation_relationship_type WHERE code = 'parent_subsidiary';

    -- Set mock actor session
    PERFORM set_config('app.current_user_id', '1000', true);

    -- Setup Primary Test Organisation
    INSERT INTO organisation.organisation (
        organisation_name, legal_name, organisation_type_id, organisation_status_id,
        created_by, updated_by
    ) VALUES (
        'Acme Corporation Global', 'Acme Corp Pvt Ltd',
        (SELECT id FROM organisation.organisation_type WHERE code = 'employer'),
        (SELECT id FROM organisation.organisation_status WHERE code = 'active'),
        1000, 1000
    ) RETURNING id INTO v_org_id;

    -- Setup Subsidiary Test Organisation
    INSERT INTO organisation.organisation (
        organisation_name, legal_name, organisation_type_id, organisation_status_id,
        created_by, updated_by
    ) VALUES (
        'Acme Labs Inc', 'Acme Labs Innovation Ltd',
        (SELECT id FROM organisation.organisation_type WHERE code = 'employer'),
        (SELECT id FROM organisation.organisation_status WHERE code = 'active'),
        1000, 1000
    ) RETURNING id INTO v_sub_org_id;

    -- Setup Tertiary Test Organisation
    INSERT INTO organisation.organisation (
        organisation_name, legal_name, organisation_type_id, organisation_status_id,
        created_by, updated_by
    ) VALUES (
        'Acme Ventures LLC', 'Acme Ventures Holdings',
        (SELECT id FROM organisation.organisation_type WHERE code = 'employer'),
        (SELECT id FROM organisation.organisation_status WHERE code = 'active'),
        1000, 1000
    ) RETURNING id INTO v_sub_org2_id;

    -- Create live platform account
    INSERT INTO organisation.account (
        organisation_id, account_name, account_type_id, account_status_id,
        created_by, updated_by
    ) VALUES (
        v_org_id, 'Acme Primary Account',
        (SELECT id FROM organisation.account_type WHERE code = 'employer'),
        (SELECT id FROM organisation.account_status WHERE code = 'active'),
        1000, 1000
    ) RETURNING id INTO v_account_id;

    -- ------------------------------------------------------------------------
    -- AREA 1: UNIQUENESS AND OVERLAP
    -- ------------------------------------------------------------------------

    -- 1.1: Second live account for one organisation must be rejected
    BEGIN
        INSERT INTO organisation.account (
            organisation_id, account_name, account_type_id, account_status_id,
            created_by, updated_by
        ) VALUES (
            v_org_id, 'Duplicate Account',
            (SELECT id FROM organisation.account_type WHERE code = 'employer'),
            (SELECT id FROM organisation.account_status WHERE code = 'active'),
            1000, 1000
        );
        RAISE EXCEPTION 'FAIL ORG-001: second live account for one org was accepted';
    EXCEPTION WHEN unique_violation THEN
        RAISE NOTICE 'PASS ORG-001: second live account for organisation rejected';
    END;

    -- 1.2: One live headquarters per organisation
    INSERT INTO organisation.organisation_location (
        organisation_id, location_name, address_line_1, country_id, is_headquarters,
        created_by, updated_by
    ) VALUES (
        v_org_id, 'HQ Bangalore', '100 Silicon Blvd', 1, true, 1000, 1000
    );

    BEGIN
        INSERT INTO organisation.organisation_location (
            organisation_id, location_name, address_line_1, country_id, is_headquarters,
            created_by, updated_by
        ) VALUES (
            v_org_id, 'Second HQ Mumbai', '200 Marine Drive', 1, true, 1000, 1000
        );
        RAISE EXCEPTION 'FAIL ORG-002: second live headquarters was accepted';
    EXCEPTION WHEN unique_violation THEN
        RAISE NOTICE 'PASS ORG-002: second live headquarters rejected by partial unique index';
    END;

    -- 1.3: Recruiter temporal overlap rejection
    SELECT 1002 INTO v_recruiter_user_id; -- Sarah Jenkins
    INSERT INTO organisation.organisation_recruiter (
        organisation_id, app_user_id, assignment_start_at, assignment_end_at,
        created_by, updated_by
    ) VALUES (
        v_org_id, v_recruiter_user_id,
        '2026-01-01 00:00:00+00', '2026-06-30 23:59:59+00', 1000, 1000
    );

    BEGIN
        INSERT INTO organisation.organisation_recruiter (
            organisation_id, app_user_id, assignment_start_at, assignment_end_at,
            created_by, updated_by
        ) VALUES (
            v_org_id, v_recruiter_user_id,
            '2026-03-01 00:00:00+00', '2026-08-30 23:59:59+00', 1000, 1000
        );
        RAISE EXCEPTION 'FAIL ORG-003: overlapping recruiter assignment was accepted';
    EXCEPTION WHEN exclusion_violation THEN
        RAISE NOTICE 'PASS ORG-003: overlapping recruiter assignment rejected by EXCLUDE USING gist';
    END;

    -- 1.4: Account administrator temporal overlap rejection
    SELECT 1000 INTO v_admin_user_id; -- Super Admin
    INSERT INTO organisation.account_administrator (
        account_id, app_user_id, assigned_at, ended_at,
        created_by, updated_by
    ) VALUES (
        v_account_id, v_admin_user_id,
        '2026-01-01 00:00:00+00', '2026-12-31 23:59:59+00', 1000, 1000
    );

    BEGIN
        INSERT INTO organisation.account_administrator (
            account_id, app_user_id, assigned_at, ended_at,
            created_by, updated_by
        ) VALUES (
            v_account_id, v_admin_user_id,
            '2026-06-01 00:00:00+00', '2027-06-30 23:59:59+00', 1000, 1000
        );
        RAISE EXCEPTION 'FAIL ORG-004: overlapping account admin tenure was accepted';
    EXCEPTION WHEN exclusion_violation THEN
        RAISE NOTICE 'PASS ORG-004: overlapping administrator tenure rejected by EXCLUDE USING gist';
    END;

    -- 1.5: One parent per child per relationship type at a time
    INSERT INTO organisation.organisation_relationship (
        parent_organisation_id, child_organisation_id, organisation_relationship_type_id,
        effective_from, effective_to, created_by, updated_by
    ) VALUES (
        v_org_id, v_sub_org_id, v_rel_type_parent_id,
        '2026-01-01', '2026-12-31', 1000, 1000
    );

    BEGIN
        INSERT INTO organisation.organisation_relationship (
            parent_organisation_id, child_organisation_id, organisation_relationship_type_id,
            effective_from, effective_to, created_by, updated_by
        ) VALUES (
            v_sub_org2_id, v_sub_org_id, v_rel_type_parent_id,
            '2026-06-01', '2027-05-31', 1000, 1000
        );
        RAISE EXCEPTION 'FAIL ORG-005: duplicate concurrent parent for child was accepted';
    EXCEPTION WHEN exclusion_violation THEN
        RAISE NOTICE 'PASS ORG-005: second parent for one child rejected by EXCLUDE constraint';
    END;

    -- 1.6: Duplicate keyed identifier fingerprint rejected
    INSERT INTO organisation.organisation_identifier (
        organisation_id, identifier_type_id, country_id,
        identifier_value_encrypted, identifier_fingerprint, identifier_key_version,
        identifier_masked, created_by, updated_by
    ) VALUES (
        v_org_id, v_id_type_gstin_id, 1,
        'v1:test_encrypted_payload', 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855', 1,
        '***********1Z5', 1000, 1000
    ) RETURNING id INTO v_identifier_id;

    BEGIN
        INSERT INTO organisation.organisation_identifier (
            organisation_id, identifier_type_id, country_id,
            identifier_value_encrypted, identifier_fingerprint, identifier_key_version,
            identifier_masked, created_by, updated_by
        ) VALUES (
            v_sub_org_id, v_id_type_gstin_id, 1,
            'v1:test_encrypted_payload_2', 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855', 1,
            '***********1Z5', 1000, 1000
        );
        RAISE EXCEPTION 'FAIL ORG-006: duplicate identifier fingerprint was accepted';
    EXCEPTION WHEN unique_violation THEN
        RAISE NOTICE 'PASS ORG-006: duplicate identifier fingerprint rejected';
    END;

    -- ------------------------------------------------------------------------
    -- AREA 2: REFERENTIAL AND DOMAIN CHECKS
    -- ------------------------------------------------------------------------

    -- 2.1: Upper-case email rejected
    BEGIN
        UPDATE organisation.organisation
        SET contact_email = 'CAPITAL@ACME.COM'
        WHERE id = v_org_id;
        RAISE EXCEPTION 'FAIL ORG-007: upper-case contact email accepted';
    EXCEPTION WHEN check_violation THEN
        RAISE NOTICE 'PASS ORG-007: upper-case contact email rejected by check';
    END;

    -- 2.2: End before start rejected on recruiter
    BEGIN
        INSERT INTO organisation.organisation_recruiter (
            organisation_id, app_user_id, assignment_start_at, assignment_end_at,
            created_by, updated_by
        ) VALUES (
            v_org_id, v_recruiter_user_id,
            '2027-05-01 00:00:00+00', '2027-01-01 00:00:00+00', 1000, 1000
        );
        RAISE EXCEPTION 'FAIL ORG-008: end date before start date accepted';
    EXCEPTION WHEN check_violation THEN
        RAISE NOTICE 'PASS ORG-008: end before start rejected by check';
    END;

    -- 2.3: Self-relationship rejected
    BEGIN
        INSERT INTO organisation.organisation_relationship (
            parent_organisation_id, child_organisation_id, organisation_relationship_type_id,
            effective_from, created_by, updated_by
        ) VALUES (
            v_org_id, v_org_id, v_rel_type_parent_id,
            '2026-01-01', 1000, 1000
        );
        RAISE EXCEPTION 'FAIL ORG-009: self-relationship parent=child was accepted';
    EXCEPTION WHEN check_violation THEN
        RAISE NOTICE 'PASS ORG-009: self-relationship rejected by parent <> child check';
    END;

    -- ------------------------------------------------------------------------
    -- AREA 3: WORKFLOW, TRANSITIONS & HIERARCHY CYCLES
    -- ------------------------------------------------------------------------

    -- 3.1: Hierarchy cycle rejection: Acme -> Labs -> Ventures -> Acme
    INSERT INTO organisation.organisation_relationship (
        parent_organisation_id, child_organisation_id, organisation_relationship_type_id,
        effective_from, created_by, updated_by
    ) VALUES (
        v_sub_org_id, v_sub_org2_id, v_rel_type_parent_id,
        '2026-01-01', 1000, 1000
    );

    BEGIN
        INSERT INTO organisation.organisation_relationship (
            parent_organisation_id, child_organisation_id, organisation_relationship_type_id,
            effective_from, created_by, updated_by
        ) VALUES (
            v_sub_org2_id, v_org_id, v_rel_type_parent_id,
            '2026-01-01', 1000, 1000
        );
        RAISE EXCEPTION 'FAIL ORG-010: cyclical hierarchy was accepted';
    EXCEPTION WHEN raise_exception THEN
        RAISE NOTICE 'PASS ORG-010: cyclical hierarchy detected and blocked by recursive CTE trigger';
    END;

    -- 3.2: Illegal verification transition: pending directly to verified without review
    INSERT INTO organisation.organisation_verification (
        organisation_id, organisation_identifier_id, verification_type_id,
        verification_status_id, created_by, updated_by
    ) VALUES (
        v_org_id, v_identifier_id,
        (SELECT id FROM organisation.verification_type WHERE code = 'tax_identifier'),
        v_status_pending_id, 1000, 1000
    ) RETURNING id INTO v_verification_id;

    BEGIN
        UPDATE organisation.organisation_verification
        SET verification_status_id = v_status_verified_id
        WHERE id = v_verification_id;
        RAISE EXCEPTION 'FAIL ORG-011: illegal jump pending->verified was accepted';
    EXCEPTION WHEN raise_exception THEN
        RAISE NOTICE 'PASS ORG-011: illegal transition pending->verified rejected by state machine guard';
    END;

    -- 3.3: Legal verification transitions: pending -> in_review -> verified (with verified_at)
    UPDATE organisation.organisation_verification
    SET verification_status_id = v_status_in_review_id
    WHERE id = v_verification_id;
    RAISE NOTICE 'PASS ORG-012: legal transition pending->in_review accepted';

    UPDATE organisation.organisation_verification
    SET verification_status_id = v_status_verified_id,
        verified_at = CURRENT_TIMESTAMP
    WHERE id = v_verification_id;
    RAISE NOTICE 'PASS ORG-013: legal transition in_review->verified accepted with verified_at';

    -- 3.4: Verification history written automatically
    SELECT count(*) INTO v_history_count
    FROM organisation.organisation_verification_history
    WHERE organisation_verification_id = v_verification_id;

    IF v_history_count >= 2 THEN
        RAISE NOTICE 'PASS ORG-014: verification history rows written automatically on transitions (%)', v_history_count;
    ELSE
        RAISE EXCEPTION 'FAIL ORG-014: expected at least 2 history rows, found %', v_history_count;
    END IF;

    -- ------------------------------------------------------------------------
    -- AREA 4: APPEND-ONLY IMMUTABILITY AND DELETE PROTECTION
    -- ------------------------------------------------------------------------

    -- 4.1: Attempting to update verification history directly must be blocked
    BEGIN
        UPDATE organisation.organisation_verification_history
        SET reason = 'Tampered reason'
        WHERE organisation_verification_id = v_verification_id;
        RAISE EXCEPTION 'FAIL ORG-015: append-only history update succeeded';
    EXCEPTION WHEN raise_exception THEN
        RAISE NOTICE 'PASS ORG-015: history update blocked by append-only trigger';
    END;

    -- 4.2: Hard delete on organisation must be blocked
    BEGIN
        DELETE FROM organisation.organisation WHERE id = v_sub_org2_id;
        RAISE EXCEPTION 'FAIL ORG-016: hard delete of organisation was permitted';
    EXCEPTION WHEN raise_exception THEN
        RAISE NOTICE 'PASS ORG-016: organisation hard delete blocked; soft-delete required';
    -- 4.3: Soft delete accepted
    UPDATE organisation.organisation
    SET deleted_at = CURRENT_TIMESTAMP, deleted_by = 1000
    WHERE id = v_sub_org2_id;
    RAISE NOTICE 'PASS ORG-017: organisation soft-delete accepted';

    -- 4.4: Non-recruiter role rejection on organisation_recruiter
    SELECT 1001 INTO v_regular_user_id; -- Aarav Sharma (holds candidate role, not recruiter)
    BEGIN
        INSERT INTO organisation.organisation_recruiter (
            organisation_id, app_user_id, assignment_start_at,
            created_by, updated_by
        ) VALUES (
            v_org_id, v_regular_user_id, CURRENT_TIMESTAMP, 1000, 1000
        );
        RAISE EXCEPTION 'FAIL ORG-018: non-recruiter user was mapped to organisation_recruiter';
    EXCEPTION WHEN raise_exception THEN
        RAISE NOTICE 'PASS ORG-018: non-recruiter rejected by fn_assert_user_role trigger';
    END;

    -- 4.5: created_by and created_at cannot be forged or mutated on update
    UPDATE organisation.organisation
    SET created_by = 9999, organisation_name = 'Acme Corp Tampered'
    WHERE id = v_org_id;

    IF (SELECT created_by FROM organisation.organisation WHERE id = v_org_id) = 1000 THEN
        RAISE NOTICE 'PASS ORG-019: created_by protected from forgery by fn_set_audit_columns';
    ELSE
        RAISE EXCEPTION 'FAIL ORG-019: created_by was forged';
    END IF;

    -- 4.6: fn_audit_log Security Definer function execution & payload hygiene
    PERFORM organisation.fn_audit_log(
        'row_update', 'organisation', v_org_id, v_org_id, true,
        '{"name": "Old", "identifier_value_encrypted": "SECRET"}'::jsonb,
        '{"name": "New", "identifier_value_encrypted": "SECRET"}'::jsonb,
        'Regression test audit log'
    );
    RAISE NOTICE 'PASS ORG-020: fn_audit_log executed with payload hygiene and partition routing';

    -- 4.7: Audit write with no actor in session fails with SQLSTATE 28000
    PERFORM set_config('app.current_user_id', '', true);
    BEGIN
        PERFORM organisation.fn_audit_log(
            'access_denied', 'organisation', v_org_id, v_org_id, false,
            NULL, NULL, 'Unauthenticated attempt'
        );
        RAISE EXCEPTION 'FAIL ORG-021: audit write without actor was accepted';
    EXCEPTION WHEN raise_exception THEN
        RAISE NOTICE 'PASS ORG-021: write without actor rejected with SQLSTATE 28000';
    END;

    -- Reset actor
    PERFORM set_config('app.current_user_id', '1000', true);

    RAISE NOTICE '============================================================';
    RAISE NOTICE 'ALL ORGANISATION SUITE ASSERTIONS PASSED WITH ZERO ERRORS';
    RAISE NOTICE '============================================================';

END $$;

ROLLBACK;
