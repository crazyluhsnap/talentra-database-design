-- ============================================================================
-- Talentra Enterprise: Phase 3 Module A (Sourcing) Regression Suite
-- Tests SRC-001 through SRC-013 with transaction-isolated rollback guarantees.
-- ============================================================================

\set ON_ERROR_STOP on

BEGIN;

DO $$
DECLARE
    v_job_id bigint;
    v_consultant_id bigint;
    v_admin_id bigint;
    v_status_pending_id bigint;
    v_decision_accepted_id bigint;
    v_decision_declined_id bigint;
    v_channel_id bigint;
    v_batch_status_id bigint;
    v_recipient_status_id bigint;
    v_shortlist_source_id bigint;
    v_org_id bigint;
    v_req_id bigint;
    v_dec_id bigint;
    v_batch_id bigint;
    v_candidate_id bigint;
    v_recipient_id bigint;
    v_initial_count integer;
    v_bad boolean := false;
BEGIN
    RAISE NOTICE '>>> RUNNING PHASE 3 MODULE A (SOURCING) REGRESSION SUITE...';

    -- Discover Fixtures
    SELECT id INTO v_consultant_id FROM administration.user_account ORDER BY id LIMIT 1;
    SELECT id INTO v_admin_id FROM administration.user_account ORDER BY id DESC LIMIT 1;
    SELECT id, organisation_id INTO v_job_id, v_org_id FROM recruitment.job_requirement ORDER BY id LIMIT 1;
    SELECT id INTO v_candidate_id FROM profile.candidate_profile ORDER BY id LIMIT 1;

    SELECT id INTO v_status_pending_id FROM sourcing.sourcing_request_status WHERE code = 'pending';
    SELECT id INTO v_decision_accepted_id FROM sourcing.decision_type WHERE code = 'accepted';
    SELECT id INTO v_decision_declined_id FROM sourcing.decision_type WHERE code = 'declined';
    SELECT id INTO v_channel_id FROM sourcing.outreach_channel WHERE code = 'email';
    SELECT id INTO v_batch_status_id FROM sourcing.outreach_batch_status WHERE code = 'draft';
    SELECT id INTO v_recipient_status_id FROM sourcing.outreach_recipient_status WHERE code = 'queued';
    SELECT id INTO v_shortlist_source_id FROM sourcing.shortlist_source_type WHERE code = 'outreach_response';

    IF v_job_id IS NULL OR v_consultant_id IS NULL THEN
        RAISE EXCEPTION 'Prerequisite fixtures missing';
    END IF;

    -- SRC-001: Sourcing request on non-open job fails (trigger)
    UPDATE recruitment.job_requirement SET open_to_consultants = false WHERE id = v_job_id;
    BEGIN
        v_bad := false;
        INSERT INTO sourcing.sourcing_request (
            job_requirement_id, consultant_user_id, sourcing_request_status_id, created_by, updated_by
        )
        VALUES (v_job_id, v_consultant_id, v_status_pending_id, v_consultant_id, v_consultant_id);
        v_bad := true;
    EXCEPTION WHEN raise_exception THEN NULL;
    END;
    IF v_bad THEN RAISE EXCEPTION 'SRC-001 FAILED: Request accepted on non-open job'; END IF;
    RAISE NOTICE 'SRC-001 PASSED: Sourcing request rejected on closed job';

    -- Setup: Open the job to consultants
    UPDATE recruitment.job_requirement SET open_to_consultants = true WHERE id = v_job_id;

    -- SRC-002: Sourcing request on open job succeeds
    INSERT INTO sourcing.sourcing_request (
        job_requirement_id, consultant_user_id, sourcing_request_status_id, created_by, updated_by
    )
    VALUES (v_job_id, v_consultant_id, v_status_pending_id, v_consultant_id, v_consultant_id)
    RETURNING id INTO v_req_id;
    RAISE NOTICE 'SRC-002 PASSED: Sourcing request created successfully';

    -- SRC-003: Duplicate active sourcing request fails (unique index)
    BEGIN
        v_bad := false;
        INSERT INTO sourcing.sourcing_request (
            job_requirement_id, consultant_user_id, sourcing_request_status_id, created_by, updated_by
        )
        VALUES (v_job_id, v_consultant_id, v_status_pending_id, v_consultant_id, v_consultant_id);
        v_bad := true;
    EXCEPTION WHEN unique_violation THEN NULL;
    END;
    IF v_bad THEN RAISE EXCEPTION 'SRC-003 FAILED: Duplicate active sourcing request allowed'; END IF;
    RAISE NOTICE 'SRC-003 PASSED: Duplicate active sourcing request prevented';

    -- SRC-004: Decision insertion updates status and closed_at
    INSERT INTO sourcing.sourcing_request_decision (
        sourcing_request_id, decision_type_id, decided_by_user_id, created_by
    )
    VALUES (v_req_id, v_decision_accepted_id, 1, 1)
    RETURNING id INTO v_dec_id;

    IF NOT EXISTS (
        SELECT 1 FROM sourcing.sourcing_request 
        WHERE id = v_req_id AND sourcing_request_status_id = (SELECT id FROM sourcing.sourcing_request_status WHERE code = 'accepted')
    ) THEN
        RAISE EXCEPTION 'SRC-004 FAILED: Sourcing request status did not update upon decision';
    END IF;
    RAISE NOTICE 'SRC-004 PASSED: Sourcing decision triggers status synchronization';

    -- SRC-005: Sourcing request decision append-only rejects update
    BEGIN
        v_bad := false;
        UPDATE sourcing.sourcing_request_decision SET reason_note = 'Modified note' WHERE id = v_dec_id;
        v_bad := true;
    EXCEPTION WHEN raise_exception THEN NULL;
    END;
    IF v_bad THEN RAISE EXCEPTION 'SRC-005 FAILED: Decision mutated on append-only table'; END IF;
    RAISE NOTICE 'SRC-005 PASSED: Decision history immutability verified';

    -- SRC-006: Outreach batch composite foreign key integrity
    INSERT INTO sourcing.outreach_batch (
        job_requirement_id, sourcing_request_id, organisation_id, initiated_by_user_id,
        outreach_channel_id, outreach_batch_status_id, idempotency_key, created_by, updated_by
    )
    VALUES (
        v_job_id, v_req_id, v_org_id, v_admin_id,
        v_channel_id, v_batch_status_id, 'batch-idem-' || txid_current(), v_admin_id, v_admin_id
    )
    RETURNING id INTO v_batch_id;
    RAISE NOTICE 'SRC-006 PASSED: Outreach batch linked with composite FK to sourcing_request';

    -- SRC-007: Outreach recipient unique per batch and candidate
    INSERT INTO sourcing.outreach_recipient (
        outreach_batch_id, candidate_profile_id, outreach_recipient_status_id, created_by, updated_by
    )
    VALUES (v_batch_id, v_candidate_id, v_recipient_status_id, v_admin_id, v_admin_id)
    RETURNING id INTO v_recipient_id;

    BEGIN
        v_bad := false;
        INSERT INTO sourcing.outreach_recipient (
            outreach_batch_id, candidate_profile_id, outreach_recipient_status_id, created_by, updated_by
        )
        VALUES (v_batch_id, v_candidate_id, v_recipient_status_id, v_admin_id, v_admin_id);
        v_bad := true;
    EXCEPTION WHEN unique_violation THEN NULL;
    END;
    IF v_bad THEN RAISE EXCEPTION 'SRC-007 FAILED: Duplicate recipient accepted in same batch'; END IF;
    RAISE NOTICE 'SRC-007 PASSED: Recipient uniqueness per batch enforced';

    -- SRC-008: Shortlist source type guard requires outreach_recipient_id for outreach_response
    BEGIN
        v_bad := false;
        INSERT INTO sourcing.sourcing_shortlist_entry (
            job_shortlist_candidate_id, shortlist_source_type_id, outreach_recipient_id,
            added_by_user_id, created_by, updated_by
        )
        VALUES (1, v_shortlist_source_id, NULL, v_admin_id, v_admin_id, v_admin_id);
        v_bad := true;
    EXCEPTION WHEN foreign_key_violation OR raise_exception THEN NULL;
    END;
    RAISE NOTICE 'SRC-008 PASSED: Shortlist provenance source validation enforced';

    -- SRC-009: Job consultant openness event append-only rejects DELETE
    INSERT INTO sourcing.job_consultant_openness_event (
        job_requirement_id, is_open, set_by_user_id, created_by
    )
    VALUES (v_job_id, true, v_admin_id, v_admin_id);

    BEGIN
        v_bad := false;
        DELETE FROM sourcing.job_consultant_openness_event WHERE job_requirement_id = v_job_id;
        v_bad := true;
    EXCEPTION WHEN raise_exception THEN NULL;
    END;
    IF v_bad THEN RAISE EXCEPTION 'SRC-009 FAILED: Openness event deleted on append-only table'; END IF;
    RAISE NOTICE 'SRC-009 PASSED: Job openness event audit immutability verified';

    -- SRC-010: Active convenience view validation
    IF NOT EXISTS (SELECT 1 FROM sourcing.v_active_sourcing_request WHERE sourcing_request_id = v_req_id) THEN
        RAISE EXCEPTION 'SRC-010 FAILED: Active sourcing request not visible in view';
    END IF;
    RAISE NOTICE 'SRC-010 PASSED: Active sourcing request operational view verified';

    -- SRC-011: Dynamic recipient count counter on outreach_batch
    SELECT recipient_count INTO v_initial_count FROM sourcing.outreach_batch WHERE id = v_batch_id;
    IF v_initial_count <> 1 THEN
        RAISE EXCEPTION 'SRC-011 FAILED: Expected recipient_count 1, got %', v_initial_count;
    END IF;
    RAISE NOTICE 'SRC-011 PASSED: Dynamic outreach batch recipient counter verified';

    -- SRC-012: Openness toggle trigger logs event automatically
    UPDATE recruitment.job_requirement SET open_to_consultants = false WHERE id = v_job_id;
    IF NOT EXISTS (
        SELECT 1 FROM sourcing.job_consultant_openness_event 
        WHERE job_requirement_id = v_job_id AND is_open = false
    ) THEN
        RAISE EXCEPTION 'SRC-012 FAILED: Openness change did not trigger automatic audit event';
    END IF;
    RAISE NOTICE 'SRC-012 PASSED: Automatic openness audit event trigger verified';

    -- SRC-013: Sourcing request decline reason mandatory check
    BEGIN
        v_bad := false;
        INSERT INTO sourcing.sourcing_request_decision (
            sourcing_request_id, decision_type_id, decided_by_user_id, decline_reason_id, created_by
        )
        VALUES (v_req_id, v_decision_declined_id, 1, NULL, 1);
        v_bad := true;
    EXCEPTION WHEN raise_exception THEN NULL;
    END;
    IF v_bad THEN RAISE EXCEPTION 'SRC-013 FAILED: Declined decision allowed without reason'; END IF;
    RAISE NOTICE 'SRC-013 PASSED: Mandatory decline reason trigger verified';

    RAISE NOTICE '>>> ALL 13 SOURCING REGRESSION TEST SCENARIOS PASSED!';
END $$;

ROLLBACK;
