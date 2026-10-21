-- ============================================================================
-- Talentra Enterprise: Phase 4 Module B (Analytics Layer) Regression Suite
-- Tests ANL-001 through ANL-012 with transaction-isolated rollback guarantees.
-- ============================================================================

\set ON_ERROR_STOP on

BEGIN;

DO $$
DECLARE
    v_cand_dim_id bigint;
    v_job_dim_id bigint;
    v_org_dim_id bigint;
    v_app_status_dim_id bigint;
    v_date_id integer := 20261021;
    v_batch_id bigint;
    v_ret_rows integer;
    v_bad boolean := false;
BEGIN
    RAISE NOTICE '>>> RUNNING PHASE 4 MODULE B (ANALYTICS LAYER) REGRESSION SUITE...';

    -- ANL-001: dim_date smart integer key and calendar constraint
    BEGIN
        v_bad := false;
        INSERT INTO analytics.dim_date (
            id, calendar_date, calendar_year, calendar_quarter, calendar_month, calendar_week,
            day_of_month, day_of_week, fiscal_year, fiscal_period, is_weekend
        ) VALUES (
            20269999, '2026-10-21', 2026, 5, 13, 42, 21, 3, 2026, 10, false
        );
        v_bad := true;
    EXCEPTION WHEN check_violation THEN NULL;
    END;
    IF v_bad THEN RAISE EXCEPTION 'ANL-001 FAILED: dim_date accepted quarter 5 and month 13'; END IF;
    RAISE NOTICE 'ANL-001 PASSED: dim_date quarter and month constraints verified';

    -- ANL-002: dim_job_category restricted 8 categories
    BEGIN
        v_bad := false;
        INSERT INTO analytics.dim_job_category (category_code, category_name)
        VALUES ('unauthorized_category', 'Invalid');
        v_bad := true;
    EXCEPTION WHEN check_violation THEN NULL;
    END;
    IF v_bad THEN RAISE EXCEPTION 'ANL-002 FAILED: dim_job_category accepted invalid category'; END IF;
    RAISE NOTICE 'ANL-002 PASSED: dim_job_category closed set validation verified';

    -- ANL-003: dim_candidate SCD2 non-overlapping GiST exclusion constraint
    INSERT INTO analytics.dim_candidate (
        source_candidate_id, candidate_pseudonym, experience_band, education_band,
        location_summary, source_channel, registration_date, effective_from, effective_to
    ) VALUES (
        99001, sha256('cand-scd-001'::bytea), '3-5 years', 'Bachelors',
        'Bangalore, India', 'direct', '2026-01-01', '2026-01-01', '2026-06-01'
    ) RETURNING id INTO v_cand_dim_id;

    BEGIN
        v_bad := false;
        INSERT INTO analytics.dim_candidate (
            source_candidate_id, candidate_pseudonym, experience_band, education_band,
            location_summary, source_channel, registration_date, effective_from, effective_to
        ) VALUES (
            99001, sha256('cand-scd-001'::bytea), '5-8 years', 'Masters',
            'Bangalore, India', 'direct', '2026-01-01', '2026-04-01', '2026-09-01'
        );
        v_bad := true;
    EXCEPTION WHEN exclusion_violation THEN NULL;
    END;
    IF v_bad THEN RAISE EXCEPTION 'ANL-003 FAILED: dim_candidate accepted overlapping SCD2 effective period'; END IF;
    RAISE NOTICE 'ANL-003 PASSED: dim_candidate SCD2 exclusion constraint verified';

    -- ANL-004: dim_organisation SCD2 exclusion constraint
    INSERT INTO analytics.dim_organisation (
        source_organisation_id, organisation_type_code, size_band_code,
        verification_status_code, country_iso_code, effective_from, effective_to
    ) VALUES (
        88001, 'enterprise', '1000+', 'verified', 'IN', '2026-01-01', '2026-07-01'
    ) RETURNING id INTO v_org_dim_id;

    BEGIN
        v_bad := false;
        INSERT INTO analytics.dim_organisation (
            source_organisation_id, organisation_type_code, size_band_code,
            verification_status_code, country_iso_code, effective_from, effective_to
        ) VALUES (
            88001, 'enterprise', '1000+', 'verified', 'IN', '2026-05-01', NULL
        );
        v_bad := true;
    EXCEPTION WHEN exclusion_violation THEN NULL;
    END;
    IF v_bad THEN RAISE EXCEPTION 'ANL-004 FAILED: dim_organisation accepted overlapping SCD2 effective period'; END IF;
    RAISE NOTICE 'ANL-004 PASSED: dim_organisation SCD2 exclusion constraint verified';

    -- ANL-005: dim_gig_worker SCD2 exclusion constraint
    INSERT INTO analytics.dim_gig_worker (
        source_gig_worker_id, worker_pseudonym, service_category_name,
        hourly_rate_band, availability_band, rating_band, effective_from, effective_to
    ) VALUES (
        77001, sha256('worker-scd-001'::bytea), 'Full Stack', '$50-$75', 'full_time', '4.5+', '2026-01-01', '2026-06-01'
    );

    BEGIN
        v_bad := false;
        INSERT INTO analytics.dim_gig_worker (
            source_gig_worker_id, worker_pseudonym, service_category_name,
            hourly_rate_band, availability_band, rating_band, effective_from, effective_to
        ) VALUES (
            77001, sha256('worker-scd-001'::bytea), 'Full Stack', '$75-$100', 'part_time', '4.8+', '2026-03-01', NULL
        );
        v_bad := true;
    EXCEPTION WHEN exclusion_violation THEN NULL;
    END;
    IF v_bad THEN RAISE EXCEPTION 'ANL-005 FAILED: dim_gig_worker accepted overlapping SCD2 period'; END IF;
    RAISE NOTICE 'ANL-005 PASSED: dim_gig_worker SCD2 exclusion constraint verified';

    -- ANL-006: load_batch window start/end check
    BEGIN
        v_bad := false;
        INSERT INTO analytics.load_batch (target_table, window_start, window_end)
        VALUES ('fact_test', '2026-10-21 12:00:00+00', '2026-10-21 10:00:00+00');
        v_bad := true;
    EXCEPTION WHEN check_violation THEN NULL;
    END;
    IF v_bad THEN RAISE EXCEPTION 'ANL-006 FAILED: load_batch accepted window_end before window_start'; END IF;
    RAISE NOTICE 'ANL-006 PASSED: load_batch window temporal constraint verified';

    -- ANL-007: fact_application_event idempotency uniqueness
    INSERT INTO analytics.load_batch (target_table, window_start, window_end)
    VALUES ('fact_application_event', '2026-10-21 00:00:00+00', '2026-10-21 04:00:00+00')
    RETURNING id INTO v_batch_id;

    INSERT INTO analytics.dim_job_requirement (
        source_job_requirement_id, dim_job_category_id, employment_type_code,
        industry_name, job_role_title, seniority_level, publish_state, effective_from, effective_to
    ) VALUES (
        66001, (SELECT id FROM analytics.dim_job_category WHERE category_code = 'permanent'),
        'full_time', 'Technology', 'Senior Architect', 'Senior', 'published', '2026-01-01', NULL
    ) RETURNING id INTO v_job_dim_id;

    SELECT id INTO v_app_status_dim_id FROM analytics.dim_application_status WHERE status_code = 'applied';

    INSERT INTO analytics.fact_application_event (
        date_id, dim_candidate_id, dim_job_requirement_id, dim_organisation_id,
        dim_application_status_id, source_system_code, source_event_id, load_batch_id
    ) VALUES (
        v_date_id, v_cand_dim_id, v_job_dim_id, v_org_dim_id,
        v_app_status_dim_id, 'talentra_core', 55001, v_batch_id
    );

    BEGIN
        v_bad := false;
        INSERT INTO analytics.fact_application_event (
            date_id, dim_candidate_id, dim_job_requirement_id, dim_organisation_id,
            dim_application_status_id, source_system_code, source_event_id, load_batch_id
        ) VALUES (
            v_date_id, v_cand_dim_id, v_job_dim_id, v_org_dim_id,
            v_app_status_dim_id, 'talentra_core', 55001, v_batch_id
        );
        v_bad := true;
    EXCEPTION WHEN unique_violation THEN NULL;
    END;
    IF v_bad THEN RAISE EXCEPTION 'ANL-007 FAILED: Duplicate ingestion permitted into fact_application_event'; END IF;
    RAISE NOTICE 'ANL-007 PASSED: Fact ingestion idempotency uniqueness verified';

    -- ANL-008: fact_application_pipeline_snapshot non-negative count
    BEGIN
        v_bad := false;
        INSERT INTO analytics.fact_application_pipeline_snapshot (
            date_id, dim_job_requirement_id, dim_organisation_id, dim_location_id,
            dim_application_status_id, application_count, load_batch_id
        ) VALUES (
            v_date_id, v_job_dim_id, v_org_dim_id, 1,
            v_app_status_dim_id, -5, v_batch_id
        );
        v_bad := true;
    EXCEPTION WHEN check_violation THEN NULL;
    END;
    IF v_bad THEN RAISE EXCEPTION 'ANL-008 FAILED: Negative application count accepted'; END IF;
    RAISE NOTICE 'ANL-008 PASSED: Fact pipeline snapshot non-negative application count verified';

    -- ANL-009: fact_gig_assignment non-negative earnings & rating range
    BEGIN
        v_bad := false;
        INSERT INTO analytics.fact_gig_assignment (
            date_id, dim_gig_worker_id, dim_job_category_id, dim_organisation_id,
            dim_location_id, dim_currency_id, agreed_price, rating_score,
            source_system_code, source_event_id, load_batch_id
        ) VALUES (
            v_date_id, 1, (SELECT id FROM analytics.dim_job_category WHERE category_code = 'gig'), v_org_dim_id,
            1, 1, 1500.00, 6.5,
            'gig_subsystem', 44001, v_batch_id
        );
        v_bad := true;
    EXCEPTION WHEN check_violation THEN NULL;
    END;
    IF v_bad THEN RAISE EXCEPTION 'ANL-009 FAILED: Rating score > 5.0 accepted'; END IF;
    RAISE NOTICE 'ANL-009 PASSED: Gig fact rating score bounded range check verified';

    -- ANL-010: agg_daily_hiring_kpi grain uniqueness
    INSERT INTO analytics.agg_daily_hiring_kpi (
        date_id, dim_location_id, dim_job_category_id, total_applications
    ) VALUES (
        v_date_id, 1, (SELECT id FROM analytics.dim_job_category WHERE category_code = 'permanent'), 45
    );
    BEGIN
        v_bad := false;
        INSERT INTO analytics.agg_daily_hiring_kpi (
            date_id, dim_location_id, dim_job_category_id, total_applications
        ) VALUES (
            v_date_id, 1, (SELECT id FROM analytics.dim_job_category WHERE category_code = 'permanent'), 60
        );
        v_bad := true;
    EXCEPTION WHEN unique_violation THEN NULL;
    END;
    IF v_bad THEN RAISE EXCEPTION 'ANL-010 FAILED: Duplicate aggregate grain entry permitted'; END IF;
    RAISE NOTICE 'ANL-010 PASSED: Aggregate hiring KPI full grain uniqueness verified';

    -- ANL-011: agg_weekly_candidate_retention percent range
    BEGIN
        v_bad := false;
        INSERT INTO analytics.agg_weekly_candidate_retention (
            registration_week_date, weeks_since_registration, active_candidates, retained_share_percent
        ) VALUES (
            '2026-10-01', 2, 100, 105.50
        );
        v_bad := true;
    EXCEPTION WHEN check_violation THEN NULL;
    END;
    IF v_bad THEN RAISE EXCEPTION 'ANL-011 FAILED: Retention percent > 100.00 accepted'; END IF;
    RAISE NOTICE 'ANL-011 PASSED: Retention share percent bounded check verified';

    -- ANL-012: Small-Cell Masking Export View (< 10 candidates masked)
    INSERT INTO analytics.agg_weekly_candidate_retention (
        registration_week_date, weeks_since_registration, active_candidates, retained_share_percent
    ) VALUES (
        '2026-10-05', 1, 6, 75.00
    );

    SELECT COUNT(*) INTO v_ret_rows 
    FROM analytics.v_executive_weekly_retention_export
    WHERE registration_week_date = '2026-10-05' AND active_candidates_masked IS NULL;

    IF v_ret_rows <> 1 THEN
        RAISE EXCEPTION 'ANL-012 FAILED: Retention view failed to mask small cell count < 10';
    END IF;
    RAISE NOTICE 'ANL-012 PASSED: Small-cell privacy export view verified (cell count < 10 masked to NULL)';

    RAISE NOTICE '>>> ALL 12 ANALYTICS LAYER REGRESSION TEST SCENARIOS PASSED!';
END $$;

ROLLBACK;
