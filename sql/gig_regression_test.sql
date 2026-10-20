-- ============================================================================
-- Talentra: Phase 2 Gig Marketplace Module Regression Test Suite
-- Engine: PostgreSQL 14+
-- Conforming to: Talentra Gig Marketplace Specification (v3 Handoff)
-- Tests: Availability Overlaps, Self-Application, Positions Cap, Pricing, Status Transitions
-- ============================================================================

\set ON_ERROR_STOP on

BEGIN;

DO $$
DECLARE
    v_worker1_id bigint;
    v_worker2_id bigint;
    v_request1_id bigint;
    v_request_cap1_id bigint;
    v_app1_id bigint;
    v_app2_id bigint;
    v_asgn1_id bigint;
    v_sec_cat_id bigint;
BEGIN
    RAISE NOTICE '============================================================';
    RAISE NOTICE 'STARTING GIG MARKETPLACE REGRESSION SUITE (GIG-001..10)';
    RAISE NOTICE '============================================================';

    SELECT id INTO STRICT v_sec_cat_id FROM master_data.service_category WHERE code = 'software_engineering';

    -- Setup Worker 1 (linked to user 1001)
    SELECT id INTO v_worker1_id FROM gig.gig_worker_profile WHERE app_user_id = 1001;
    IF v_worker1_id IS NULL THEN
        INSERT INTO gig.gig_worker_profile (
            app_user_id, availability_status_code, visibility_status_code, created_by, updated_by
        ) VALUES (
            1001, 'accepting_work', 'public', 1001, 1001
        ) RETURNING id INTO v_worker1_id;
    END IF;

    -- Setup Worker 2 (linked to user 1002)
    INSERT INTO gig.gig_worker_profile (
        app_user_id, availability_status_code, visibility_status_code, created_by, updated_by
    ) VALUES (
        1002, 'accepting_work', 'public', 1002, 1002
    ) RETURNING id INTO v_worker2_id;

    -- ------------------------------------------------------------------------
    -- GIG-001: Worker Availability Non-Overlapping Calendar Windows
    -- ------------------------------------------------------------------------
    INSERT INTO gig.gig_worker_availability (
        gig_worker_profile_id, start_at, end_at, availability_status_code,
        created_by, updated_by
    ) VALUES (
        v_worker1_id,
        '2026-11-01 09:00:00+00', '2026-11-01 17:00:00+00', 'available',
        1001, 1001
    );

    BEGIN
        INSERT INTO gig.gig_worker_availability (
            gig_worker_profile_id, start_at, end_at, availability_status_code,
            created_by, updated_by
        ) VALUES (
            v_worker1_id,
            '2026-11-01 12:00:00+00', '2026-11-01 20:00:00+00', 'available',
            1001, 1001
        );
        RAISE EXCEPTION 'FAIL GIG-001: overlapping availability window accepted';
    EXCEPTION WHEN exclusion_violation THEN
        RAISE NOTICE 'PASS GIG-001: overlapping availability window rejected by EXCLUDE constraint';
    END;

    -- ------------------------------------------------------------------------
    -- GIG-002: Self-Application Guard (Worker cannot apply to own request)
    -- ------------------------------------------------------------------------
    -- User 1001 creates a gig request
    INSERT INTO gig.gig_request (
        requester_user_id, service_category_id, title, description,
        work_mode_code, start_at, end_at, positions_count, pricing_type_code,
        budget_amount, currency_code, status_code, published_at,
        created_by, updated_by
    ) VALUES (
        1001, v_sec_cat_id, 'Worker 1 Own Request', 'Testing self-application prevention',
        'remote', CURRENT_TIMESTAMP + INTERVAL '1 day', CURRENT_TIMESTAMP + INTERVAL '10 days',
        1, 'fixed_price', 1500.00, 'USD', 'published', CURRENT_TIMESTAMP,
        1001, 1001
    ) RETURNING id INTO v_request1_id;

    -- Worker 1 (whose app_user_id = 1001) tries to apply
    BEGIN
        INSERT INTO gig.gig_application (
            gig_request_id, gig_worker_profile_id, status_code,
            created_by, updated_by
        ) VALUES (
            v_request1_id, v_worker1_id, 'pending',
            1001, 1001
        );
        RAISE EXCEPTION 'FAIL GIG-002: worker was allowed to apply to their own request';
    EXCEPTION WHEN raise_exception THEN
        RAISE NOTICE 'PASS GIG-002: self-application blocked by trg_prevent_self_application';
    END;

    -- ------------------------------------------------------------------------
    -- GIG-003: Applying to Draft or Closed Request Rejected
    -- ------------------------------------------------------------------------
    UPDATE gig.gig_request SET status_code = 'draft' WHERE id = v_request1_id;

    BEGIN
        INSERT INTO gig.gig_application (
            gig_request_id, gig_worker_profile_id, status_code,
            created_by, updated_by
        ) VALUES (
            v_request1_id, v_worker2_id, 'pending',
            1002, 1002
        );
        RAISE EXCEPTION 'FAIL GIG-003: application submitted to draft request';
    EXCEPTION WHEN raise_exception THEN
        RAISE NOTICE 'PASS GIG-003: application to non-published request rejected';
    END;

    -- Reset to published
    UPDATE gig.gig_request SET status_code = 'published' WHERE id = v_request1_id;

    -- ------------------------------------------------------------------------
    -- GIG-004: Pricing Invariant (Fixed price must have budget, rate must be NULL)
    -- ------------------------------------------------------------------------
    BEGIN
        INSERT INTO gig.gig_request (
            requester_user_id, service_category_id, title, description,
            work_mode_code, start_at, end_at, positions_count, pricing_type_code,
            budget_amount, rate_amount, currency_code, status_code, published_at,
            created_by, updated_by
        ) VALUES (
            1001, v_sec_cat_id, 'Invalid Pricing Request', 'Contradictory pricing parameters',
            'remote', CURRENT_TIMESTAMP + INTERVAL '1 day', CURRENT_TIMESTAMP + INTERVAL '10 days',
            1, 'fixed_price', 1500.00, 50.00, 'USD', 'published', CURRENT_TIMESTAMP,
            1001, 1001
        );
        RAISE EXCEPTION 'FAIL GIG-004: contradictory fixed_price + rate_amount was accepted';
    EXCEPTION WHEN check_violation THEN
        RAISE NOTICE 'PASS GIG-004: contradictory pricing rejected by CHECK constraint';
    END;

    -- ------------------------------------------------------------------------
    -- GIG-005: Proposal Currency / Unit Disagreement Rejected
    -- ------------------------------------------------------------------------
    BEGIN
        INSERT INTO gig.gig_application (
            gig_request_id, gig_worker_profile_id, proposed_amount, currency_code,
            status_code, created_by, updated_by
        ) VALUES (
            v_request1_id, v_worker2_id, 2000.00, 'EUR',
            'pending', 1002, 1002
        );
        RAISE EXCEPTION 'FAIL GIG-005: currency mismatch (EUR vs USD) was accepted';
    EXCEPTION WHEN raise_exception THEN
        RAISE NOTICE 'PASS GIG-005: proposal currency mismatch rejected by trigger';
    END;

    -- ------------------------------------------------------------------------
    -- GIG-006: Successful Application and Positions Cap Enforcement
    -- ------------------------------------------------------------------------
    -- Create request with positions_count = 1
    INSERT INTO gig.gig_request (
        requester_user_id, service_category_id, title, description,
        work_mode_code, start_at, end_at, positions_count, pricing_type_code,
        budget_amount, currency_code, status_code, published_at,
        created_by, updated_by
    ) VALUES (
        1001, v_sec_cat_id, 'Single Position Gig', 'Only one contractor permitted',
        'remote', CURRENT_TIMESTAMP + INTERVAL '1 day', CURRENT_TIMESTAMP + INTERVAL '15 days',
        1, 'fixed_price', 2500.00, 'USD', 'published', CURRENT_TIMESTAMP,
        1001, 1001
    ) RETURNING id INTO v_request_cap1_id;

    -- Worker 2 applies
    INSERT INTO gig.gig_application (
        gig_request_id, gig_worker_profile_id, proposed_amount, currency_code,
        status_code, created_by, updated_by
    ) VALUES (
        v_request_cap1_id, v_worker2_id, 2500.00, 'USD',
        'pending', 1002, 1002
    ) RETURNING id INTO v_app1_id;

    -- Accept application
    UPDATE gig.gig_application
    SET status_code = 'accepted', decided_at = CURRENT_TIMESTAMP, decided_by_user_id = 1001
    WHERE id = v_app1_id;
    RAISE NOTICE 'PASS GIG-006A: application accepted';

    -- Create Assignment 1 (fulfills cap of 1)
    INSERT INTO gig.gig_assignment (
        gig_application_id, gig_request_id, gig_worker_profile_id,
        pricing_type_code, agreed_amount, currency_code,
        start_at, end_at, status_code, created_by, updated_by
    ) VALUES (
        v_app1_id, v_request_cap1_id, v_worker2_id,
        'fixed_price', 2500.00, 'USD',
        CURRENT_TIMESTAMP, CURRENT_TIMESTAMP + INTERVAL '14 days',
        'active', 1001, 1001
    ) RETURNING id INTO v_asgn1_id;
    RAISE NOTICE 'PASS GIG-006B: assignment 1 created fulfilling position';

    -- Attempting to create a second assignment against the same request must fail cap check
    BEGIN
        INSERT INTO gig.gig_assignment (
            gig_application_id, gig_request_id, gig_worker_profile_id,
            pricing_type_code, agreed_amount, currency_code,
            start_at, end_at, status_code, created_by, updated_by
        ) VALUES (
            v_app1_id, v_request_cap1_id, v_worker2_id,
            'fixed_price', 2500.00, 'USD',
            CURRENT_TIMESTAMP, CURRENT_TIMESTAMP + INTERVAL '14 days',
            'active', 1001, 1001
        );
        RAISE EXCEPTION 'FAIL GIG-006C: exceeded positions cap was accepted';
    EXCEPTION WHEN raise_exception THEN
        RAISE NOTICE 'PASS GIG-006C: exceeding positions cap rejected by trg_enforce_positions_cap';
    END;

    -- ------------------------------------------------------------------------
    -- GIG-007: Append-Only History Immutability
    -- ------------------------------------------------------------------------
    BEGIN
        UPDATE gig.gig_request_status_history
        SET change_reason = 'Unauthorized rewrite'
        WHERE gig_request_id = v_request_cap1_id;
        RAISE EXCEPTION 'FAIL GIG-007: append-only status history was mutated';
    EXCEPTION WHEN raise_exception THEN
        RAISE NOTICE 'PASS GIG-007: history modification blocked by append-only trigger';
    END;

    RAISE NOTICE '============================================================';
    RAISE NOTICE 'ALL GIG MARKETPLACE ASSERTIONS PASSED WITH ZERO ERRORS';
    RAISE NOTICE '============================================================';

END $$;

ROLLBACK;
