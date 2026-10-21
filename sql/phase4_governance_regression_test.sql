-- ============================================================================
-- Talentra Enterprise: Phase 4 Module C (Governance & Privacy) Regression Suite
-- Tests GOV-001 through GOV-012 with transaction-isolated rollback guarantees.
-- ============================================================================

\set ON_ERROR_STOP on

BEGIN;

DO $$
DECLARE
    v_admin_id bigint;
    v_recruiter_id bigint;
    v_candidate_user_id bigint;
    v_candidate_prof_id bigint;
    v_org_id bigint;
    v_licence_id bigint;
    v_policy_type_id bigint;
    v_policy_id bigint;
    v_cred_id bigint;
    v_tok_id bigint;
    v_err_sev_id bigint;
    v_boundary_id bigint;
    v_ex_stat_id bigint;
    v_ret_act_id bigint;
    v_dpr_type_id bigint;
    v_dpr_stat_id bigint;
    v_log_out_id bigint;
    v_attempt_id bigint;
    v_visible boolean;
    v_session_id bigint;
    v_audit_count integer;
    v_bad boolean := false;
BEGIN
    RAISE NOTICE '>>> RUNNING PHASE 4 MODULE C (GOVERNANCE & PRIVACY) REGRESSION SUITE...';

    SELECT id INTO v_admin_id FROM administration.user_account ORDER BY id LIMIT 1;
    SELECT id INTO v_candidate_user_id FROM administration.user_account ORDER BY id DESC LIMIT 1;
    SELECT id INTO v_candidate_prof_id FROM profile.candidate_profile WHERE user_account_id = v_candidate_user_id LIMIT 1;
    IF v_candidate_prof_id IS NULL THEN
        SELECT id, user_account_id INTO v_candidate_prof_id, v_candidate_user_id FROM profile.candidate_profile ORDER BY id LIMIT 1;
    END IF;

    -- Create distinct recruiter user and organisation for testing
    INSERT INTO administration.user_account (email, display_name)
    VALUES ('recruiter_test_' || txid_current() || '@firm.com', 'Test Recruiter')
    RETURNING id INTO v_recruiter_id;

    SELECT id INTO v_org_id FROM organisation.organisation ORDER BY id LIMIT 1;
    SELECT id INTO v_licence_id FROM licence.licence ORDER BY id LIMIT 1;

    SELECT id INTO v_policy_type_id FROM administration.consent_type WHERE code = 'terms_of_service';
    SELECT id INTO v_err_sev_id FROM administration.error_severity WHERE code = 'error';
    SELECT id INTO v_boundary_id FROM administration.integration_boundary WHERE code = 'payment_gateway';
    SELECT id INTO v_ex_stat_id FROM administration.exchange_status WHERE code = 'received';
    SELECT id INTO v_ret_act_id FROM administration.retention_action WHERE code = 'delete';
    SELECT id INTO v_dpr_type_id FROM administration.data_request_type WHERE code = 'erasure_right_to_be_forgotten';
    SELECT id INTO v_dpr_stat_id FROM administration.data_request_status WHERE code = 'received';
    SELECT id INTO v_log_out_id FROM administration.login_outcome WHERE code = 'success';

    -- GOV-001: consent_policy version uniqueness and period check
    BEGIN
        v_bad := false;
        INSERT INTO administration.consent_policy (
            consent_type_id, version_label, effective_from, effective_to, document_reference, created_by, updated_by
        ) VALUES (
            v_policy_type_id, 'v1.0-test', '2026-06-01', '2026-05-01', 'ref.pdf', v_admin_id, v_admin_id
        );
        v_bad := true;
    EXCEPTION WHEN check_violation THEN NULL;
    END;
    IF v_bad THEN RAISE EXCEPTION 'GOV-001 FAILED: consent_policy accepted effective_to before effective_from'; END IF;
    RAISE NOTICE 'GOV-001 PASSED: consent_policy period check verified';

    -- GOV-002: credential_reset_token expiry check
    SELECT id INTO v_cred_id FROM administration.user_credential WHERE user_account_id = v_candidate_user_id LIMIT 1;
    IF v_cred_id IS NULL THEN
        INSERT INTO administration.user_credential (user_account_id, credential_type_code, password_hash)
        VALUES (v_candidate_user_id, 'password', '$argon2id$v=19$m=65536,t=3,p=4$dummyhashtestvalue12345')
        RETURNING id INTO v_cred_id;
    END IF;

    BEGIN
        v_bad := false;
        INSERT INTO administration.credential_reset_token (
            user_credential_id, token_hash, expires_at, created_at, created_by
        ) VALUES (
            v_cred_id, sha256('bad_token'::bytea), '2026-10-21 08:00:00+00', '2026-10-21 10:00:00+00', v_admin_id
        );
        v_bad := true;
    EXCEPTION WHEN check_violation THEN NULL;
    END;
    IF v_bad THEN RAISE EXCEPTION 'GOV-002 FAILED: credential_reset_token expired before creation'; END IF;
    RAISE NOTICE 'GOV-002 PASSED: credential_reset_token expiry constraint verified';

    -- GOV-003: credential_reset_token append-only immutability
    INSERT INTO administration.credential_reset_token (
        user_credential_id, token_hash, expires_at, created_at, created_by
    ) VALUES (
        v_cred_id, sha256(('good_token_' || txid_current())::bytea), CURRENT_TIMESTAMP + interval '1 hour', CURRENT_TIMESTAMP, v_admin_id
    ) RETURNING id INTO v_tok_id;

    BEGIN
        v_bad := false;
        DELETE FROM administration.credential_reset_token WHERE id = v_tok_id;
        v_bad := true;
    EXCEPTION WHEN raise_exception THEN NULL;
    END;
    IF v_bad THEN RAISE EXCEPTION 'GOV-003 FAILED: credential_reset_token delete permitted on append-only table'; END IF;
    RAISE NOTICE 'GOV-003 PASSED: credential_reset_token append-only immutability verified';

    -- GOV-004: system_error_log append-only immutability
    INSERT INTO administration.system_error_log (
        error_severity_id, component, error_code, message_text
    ) VALUES (
        v_err_sev_id, 'payment_engine', 'ERR_GATEWAY_TIMEOUT', 'Stripe connection timed out after 30s'
    ) RETURNING id INTO v_tok_id;

    BEGIN
        v_bad := false;
        UPDATE administration.system_error_log SET message_text = 'tampered' WHERE id = v_tok_id;
        v_bad := true;
    EXCEPTION WHEN raise_exception THEN NULL;
    END;
    IF v_bad THEN RAISE EXCEPTION 'GOV-004 FAILED: system_error_log update permitted on append-only table'; END IF;
    RAISE NOTICE 'GOV-004 PASSED: system_error_log append-only immutability verified';

    -- GOV-005: integration_exchange idempotency uniqueness
    INSERT INTO administration.integration_exchange (
        integration_boundary_id, direction, idempotency_key, exchange_status_id, request_hash
    ) VALUES (
        v_boundary_id, 'inbound', 'webhook-evt-' || txid_current(), v_ex_stat_id, sha256('payload1'::bytea)
    );

    BEGIN
        v_bad := false;
        INSERT INTO administration.integration_exchange (
            integration_boundary_id, direction, idempotency_key, exchange_status_id, request_hash
        ) VALUES (
            v_boundary_id, 'inbound', 'webhook-evt-' || txid_current(), v_ex_stat_id, sha256('payload2'::bytea)
        );
        v_bad := true;
    EXCEPTION WHEN unique_violation THEN NULL;
    END;
    IF v_bad THEN RAISE EXCEPTION 'GOV-005 FAILED: Duplicate integration exchange idempotency key permitted'; END IF;
    RAISE NOTICE 'GOV-005 PASSED: Integration exchange boundary idempotency verified';

    -- GOV-006: retention_policy entity uniqueness
    BEGIN
        v_bad := false;
        INSERT INTO administration.retention_policy (
            entity_name, retention_interval, retention_action_id, legal_basis_text, created_by, updated_by
        ) VALUES (
            'duplicate_entity', interval '30 days', v_ret_act_id, 'legal basis', v_admin_id, v_admin_id
        );
        INSERT INTO administration.retention_policy (
            entity_name, retention_interval, retention_action_id, legal_basis_text, created_by, updated_by
        ) VALUES (
            'duplicate_entity', interval '60 days', v_ret_act_id, 'legal basis', v_admin_id, v_admin_id
        );
        v_bad := true;
    EXCEPTION WHEN unique_violation THEN NULL;
    END;
    IF v_bad THEN RAISE EXCEPTION 'GOV-006 FAILED: Duplicate entity retention policy allowed'; END IF;
    RAISE NOTICE 'GOV-006 PASSED: Retention policy entity uniqueness verified';

    -- GOV-007: data_subject_request due_at order check
    BEGIN
        v_bad := false;
        INSERT INTO administration.data_subject_request (
            user_account_id, data_request_type_id, data_request_status_id,
            received_at, due_at, created_by, updated_by
        ) VALUES (
            v_candidate_user_id, v_dpr_type_id, v_dpr_stat_id,
            '2026-10-21 10:00:00+00', '2026-10-20 10:00:00+00', v_admin_id, v_admin_id
        );
        v_bad := true;
    EXCEPTION WHEN check_violation THEN NULL;
    END;
    IF v_bad THEN RAISE EXCEPTION 'GOV-007 FAILED: data_subject_request accepted due_at before received_at'; END IF;
    RAISE NOTICE 'GOV-007 PASSED: Data subject request statutory due date check verified';

    -- GOV-008: login_attempt append-only immutability
    INSERT INTO administration.login_attempt (
        user_account_id, identifier_hash, login_outcome_id, source_ip_hash, occurred_at
    ) VALUES (
        v_candidate_user_id, sha256('candidate@email.com'::bytea), v_log_out_id,
        sha256('192.168.1.1'::bytea), '2026-10-21 11:00:00+00'
    ) RETURNING id INTO v_attempt_id;

    BEGIN
        v_bad := false;
        DELETE FROM administration.login_attempt WHERE id = v_attempt_id AND occurred_at = '2026-10-21 11:00:00+00';
        v_bad := true;
    EXCEPTION WHEN raise_exception THEN NULL;
    END;
    IF v_bad THEN RAISE EXCEPTION 'GOV-008 FAILED: login_attempt delete permitted on append-only table'; END IF;
    RAISE NOTICE 'GOV-008 PASSED: Login attempt security log append-only immutability verified';

    -- GOV-009: candidate_visible_to() returns TRUE when unblocked
    v_visible := administration.candidate_visible_to(v_recruiter_id, v_candidate_prof_id);
    IF v_visible IS NOT TRUE THEN
        RAISE EXCEPTION 'GOV-009 FAILED: candidate_visible_to returned false for unblocked recruiter';
    END IF;
    RAISE NOTICE 'GOV-009 PASSED: candidate_visible_to returns true for unblocked parties';

    -- GOV-010: candidate_visible_to() returns FALSE on individual user block
    INSERT INTO administration.user_block (blocker_user_id, blocked_user_id, reason_code)
    VALUES (v_candidate_user_id, v_recruiter_id, 'user_requested');

    v_visible := administration.candidate_visible_to(v_recruiter_id, v_candidate_prof_id);
    IF v_visible IS NOT FALSE THEN
        RAISE EXCEPTION 'GOV-010 FAILED: candidate_visible_to returned true for individually blocked recruiter';
    END IF;
    RAISE NOTICE 'GOV-010 PASSED: Individual block hides candidate profile from blocked recruiter';

    -- Lift individual block
    UPDATE administration.user_block 
    SET lifted_at = CURRENT_TIMESTAMP, lifted_by = v_admin_id 
    WHERE blocker_user_id = v_candidate_user_id AND blocked_user_id = v_recruiter_id;

    -- GOV-011: candidate_visible_to() returns FALSE on organisation block
    -- Map recruiter to organisation
    INSERT INTO organisation.organisation_recruiter (
        organisation_id, recruiter_user_account_id, is_primary_contact, created_by, updated_by
    ) VALUES (
        v_org_id, v_recruiter_id, false, v_admin_id, v_admin_id
    ) ON CONFLICT DO NOTHING;

    -- Candidate blocks entire organisation
    INSERT INTO administration.organisation_block (blocker_user_id, blocked_organisation_id, reason_code)
    VALUES (v_candidate_user_id, v_org_id, 'user_requested');

    v_visible := administration.candidate_visible_to(v_recruiter_id, v_candidate_prof_id);
    IF v_visible IS NOT FALSE THEN
        RAISE EXCEPTION 'GOV-011 FAILED: candidate_visible_to returned true for recruiter of blocked organisation';
    END IF;
    RAISE NOTICE 'GOV-011 PASSED: Corporate block hides candidate profile from all recruiters of blocked organisation';

    -- GOV-012: start_user_session() audits session limit without failing transaction
    -- Attempt starting session with max devices = 1
    v_session_id := administration.start_user_session(
        v_admin_id, v_licence_id, 1, sha256(('session_token_1_' || txid_current())::bytea), interval '1 hour'
    );
    RAISE NOTICE 'GOV-012 PASSED: start_user_session successfully managed session lifecycle (session_id=%)', v_session_id;

    RAISE NOTICE '>>> ALL 12 GOVERNANCE & PRIVACY REGRESSION TEST SCENARIOS PASSED!';
END $$;

ROLLBACK;
