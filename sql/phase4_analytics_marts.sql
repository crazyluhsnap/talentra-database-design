-- ============================================================================
-- Talentra Enterprise Database Architecture
-- Phase 4 - Module B: Analytics Layer & Reporting Marts (analytics)
-- PostgreSQL 16+
--
-- Conforming to:
-- - Talentra Phase 4: Entities and Relationships Specification (Module B)
-- - Talentra Phase 4: Gap Analysis and Revised Schema (Gaps B01 - B12)
--
-- Entities:
-- 1. 5 ETL & Control Tables:
--    - load_batch, load_reject, load_watermark, recon_check, fx_rate
-- 2. 18 Star-Schema Dimensions:
--    - dim_date (Smart yyyymmdd integer PK)
--    - dim_candidate (SCD2, pseudonym, banded attributes)
--    - dim_job_requirement (SCD2)
--    - dim_job_category (SCD1, 8 business categories)
--    - dim_organisation (SCD2)
--    - dim_user (SCD1, actor role only)
--    - dim_gig_worker (SCD2, rating/availability bands)
--    - dim_location (SCD1)
--    - dim_job_status (SCD1)
--    - dim_application_status (SCD1)
--    - dim_subscription_plan (SCD2)
--    - dim_licence (SCD2)
--    - dim_channel (SCD1)
--    - dim_notification_type (SCD1)
--    - dim_credit_event_type (SCD1)
--    - dim_support_category (SCD1)
--    - dim_currency (SCD1)
--    - dim_language (SCD1)
-- 3. 16 Star-Schema Fact Tables (Partitioned by date_id):
--    - fact_application_event
--    - fact_application_pipeline_snapshot
--    - fact_job_snapshot
--    - fact_candidate_activity
--    - fact_profile_view
--    - fact_profile_download
--    - fact_sourcing_activity
--    - fact_gig_application_event
--    - fact_gig_assignment
--    - fact_subscription_event
--    - fact_payment_transaction
--    - fact_wallet_transaction
--    - fact_licence_utilisation_snapshot
--    - fact_notification_delivery
--    - fact_support_ticket
--    - fact_referral_event
-- 4. 9 Daily & Weekly Aggregate KPI Marts:
--    - agg_daily_hiring_kpi
--    - agg_daily_candidate_activity
--    - agg_daily_sourcing_kpi
--    - agg_daily_revenue_kpi
--    - agg_daily_notification_kpi
--    - agg_daily_gig_kpi
--    - agg_daily_wallet_kpi
--    - agg_daily_support_kpi
--    - agg_weekly_candidate_retention
-- ============================================================================

\set ON_ERROR_STOP on

BEGIN;

CREATE EXTENSION IF NOT EXISTS btree_gist;

CREATE SCHEMA IF NOT EXISTS analytics;

-- ============================================================================
-- 1. ETL CONTROL & RECONCILIATION TABLES (Section B.4)
-- ============================================================================

CREATE TABLE analytics.load_batch (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    target_table varchar(100) NOT NULL,
    window_start timestamptz NOT NULL,
    window_end timestamptz NOT NULL,
    started_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    finished_at timestamptz NULL,
    rows_loaded bigint NULL,
    rows_rejected bigint NULL,
    CONSTRAINT ck_load_batch_window CHECK (window_end > window_start)
);

CREATE TABLE analytics.load_reject (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    load_batch_id bigint NOT NULL REFERENCES analytics.load_batch(id) ON UPDATE NO ACTION ON DELETE CASCADE,
    source_id varchar(150) NOT NULL,
    reason_text text NOT NULL,
    occurred_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE analytics.load_watermark (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    target_table varchar(100) NOT NULL,
    last_good_window_end timestamptz NOT NULL,
    updated_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_load_watermark_target UNIQUE (target_table)
);

-- ============================================================================
-- 2. STAR SCHEMA DIMENSIONS (18 Dimensions, SCD1 & SCD2)
-- ============================================================================

-- Deviation D3: dim_date uses integer YYYYMMDD PK for partition readability
CREATE TABLE analytics.dim_date (
    id integer NOT NULL PRIMARY KEY, -- yyyymmdd
    calendar_date date NOT NULL UNIQUE,
    calendar_year smallint NOT NULL,
    calendar_quarter smallint NOT NULL,
    calendar_month smallint NOT NULL,
    calendar_week smallint NOT NULL,
    day_of_month smallint NOT NULL,
    day_of_week smallint NOT NULL,
    fiscal_year smallint NOT NULL,
    fiscal_period smallint NOT NULL,
    is_weekend boolean NOT NULL,
    CONSTRAINT ck_dim_date_quarter CHECK (calendar_quarter BETWEEN 1 AND 4),
    CONSTRAINT ck_dim_date_month CHECK (calendar_month BETWEEN 1 AND 12)
);

CREATE TABLE analytics.dim_currency (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    currency_code char(3) NOT NULL,
    currency_name varchar(80) NOT NULL,
    minor_units smallint NOT NULL DEFAULT 2,
    CONSTRAINT uq_dim_currency_code UNIQUE (currency_code)
);

CREATE TABLE analytics.fx_rate (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    dim_currency_id bigint NOT NULL REFERENCES analytics.dim_currency(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    rate_date date NOT NULL,
    rate_to_usd numeric(18,6) NOT NULL CHECK (rate_to_usd > 0),
    created_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_fx_rate_currency_date UNIQUE (dim_currency_id, rate_date)
);

CREATE TABLE analytics.recon_check (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    date_id integer NOT NULL REFERENCES analytics.dim_date(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    dim_currency_id bigint NOT NULL REFERENCES analytics.dim_currency(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    analytics_total numeric(14,2) NOT NULL,
    billing_ledger_total numeric(14,2) NOT NULL,
    is_matched boolean NOT NULL,
    checked_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_recon_check_date_curr UNIQUE (date_id, dim_currency_id)
);

CREATE TABLE analytics.dim_language (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    language_code varchar(10) NOT NULL,
    language_name varchar(100) NOT NULL,
    CONSTRAINT uq_dim_language_code UNIQUE (language_code)
);

CREATE TABLE analytics.dim_location (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    city_name varchar(100) NOT NULL,
    state_name varchar(100) NOT NULL,
    country_name varchar(100) NOT NULL,
    country_iso_code char(2) NOT NULL
);

CREATE TABLE analytics.dim_job_category (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    category_code varchar(50) NOT NULL,
    category_name varchar(100) NOT NULL,
    CONSTRAINT uq_dim_job_category_code UNIQUE (category_code),
    CONSTRAINT ck_dim_job_category_set CHECK (category_code IN (
        'gig', 'general_staffing', 'professional_staffing', 'permanent',
        'apprentice', 'campus', 'consultant_marketplace', 'managed_remote'
    ))
);

CREATE TABLE analytics.dim_job_status (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    status_code varchar(50) NOT NULL,
    status_group varchar(50) NOT NULL,
    is_terminal boolean NOT NULL DEFAULT false,
    sort_order integer NOT NULL DEFAULT 0,
    CONSTRAINT uq_dim_job_status_code UNIQUE (status_code)
);

CREATE TABLE analytics.dim_application_status (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    status_code varchar(50) NOT NULL,
    status_group varchar(50) NOT NULL,
    outcome_class varchar(50) NOT NULL,
    is_terminal boolean NOT NULL DEFAULT false,
    sort_order integer NOT NULL DEFAULT 0,
    CONSTRAINT uq_dim_app_status_code UNIQUE (status_code)
);

CREATE TABLE analytics.dim_channel (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    channel_code varchar(50) NOT NULL,
    channel_group varchar(50) NOT NULL,
    CONSTRAINT uq_dim_channel_code UNIQUE (channel_code)
);

CREATE TABLE analytics.dim_notification_type (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    type_code varchar(50) NOT NULL,
    is_mandatory boolean NOT NULL DEFAULT false,
    type_group varchar(50) NOT NULL,
    CONSTRAINT uq_dim_notification_type_code UNIQUE (type_code)
);

CREATE TABLE analytics.dim_credit_event_type (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    event_code varchar(50) NOT NULL,
    event_group varchar(50) NOT NULL,
    CONSTRAINT uq_dim_credit_event_type_code UNIQUE (event_code),
    CONSTRAINT ck_dim_credit_event_code CHECK (event_code IN (
        'recharge', 'posting', 'download', 'outreach', 'refund', 'referral_reward'
    ))
);

CREATE TABLE analytics.dim_support_category (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    category_code varchar(50) NOT NULL,
    priority_group varchar(50) NOT NULL,
    CONSTRAINT uq_dim_support_category_code UNIQUE (category_code)
);

CREATE TABLE analytics.dim_user (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    source_user_account_id bigint NOT NULL,
    actor_role_code varchar(50) NOT NULL,
    member_type_code varchar(30) NOT NULL DEFAULT 'regular' CHECK (member_type_code IN ('regular', 'unknown', 'not_applicable'))
);

CREATE INDEX idx_dim_user_source ON analytics.dim_user(source_user_account_id);

-- SCD2 Dimensions with GiST Non-Overlapping Exclusion Constraints
CREATE TABLE analytics.dim_candidate (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    source_candidate_id bigint NOT NULL,
    candidate_pseudonym bytea NOT NULL, -- Keyed HMAC hash
    experience_band varchar(50) NOT NULL,
    education_band varchar(50) NOT NULL,
    location_summary varchar(100) NOT NULL,
    source_channel varchar(50) NOT NULL,
    registration_date date NOT NULL,
    member_type_code varchar(30) NOT NULL DEFAULT 'regular' CHECK (member_type_code IN ('regular', 'unknown', 'not_applicable')),
    effective_from date NOT NULL,
    effective_to date NULL, -- NULL = open-ended current
    is_current boolean GENERATED ALWAYS AS (effective_to IS NULL) STORED,
    CONSTRAINT ck_dim_candidate_period CHECK (effective_to IS NULL OR effective_to > effective_from),
    CONSTRAINT ex_dim_candidate_period EXCLUDE USING gist (
        source_candidate_id WITH =,
        daterange(effective_from, effective_to, '[)') WITH &&
    )
);

CREATE UNIQUE INDEX uq_dim_candidate_current ON analytics.dim_candidate(source_candidate_id) WHERE is_current = true;

CREATE TABLE analytics.dim_job_requirement (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    source_job_requirement_id bigint NOT NULL,
    dim_job_category_id bigint NOT NULL REFERENCES analytics.dim_job_category(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    employment_type_code varchar(50) NOT NULL,
    industry_name varchar(100) NOT NULL,
    job_role_title varchar(100) NOT NULL,
    seniority_level varchar(50) NOT NULL,
    publish_state varchar(50) NOT NULL,
    open_to_consultants boolean NOT NULL DEFAULT false,
    effective_from date NOT NULL,
    effective_to date NULL,
    is_current boolean GENERATED ALWAYS AS (effective_to IS NULL) STORED,
    CONSTRAINT ck_dim_job_requirement_period CHECK (effective_to IS NULL OR effective_to > effective_from),
    CONSTRAINT ex_dim_job_requirement_period EXCLUDE USING gist (
        source_job_requirement_id WITH =,
        daterange(effective_from, effective_to, '[)') WITH &&
    )
);

CREATE UNIQUE INDEX uq_dim_job_requirement_current ON analytics.dim_job_requirement(source_job_requirement_id) WHERE is_current = true;

CREATE TABLE analytics.dim_organisation (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    source_organisation_id bigint NOT NULL,
    organisation_type_code varchar(50) NOT NULL,
    size_band_code varchar(50) NOT NULL,
    verification_status_code varchar(50) NOT NULL,
    country_iso_code char(2) NOT NULL,
    effective_from date NOT NULL,
    effective_to date NULL,
    is_current boolean GENERATED ALWAYS AS (effective_to IS NULL) STORED,
    CONSTRAINT ck_dim_organisation_period CHECK (effective_to IS NULL OR effective_to > effective_from),
    CONSTRAINT ex_dim_organisation_period EXCLUDE USING gist (
        source_organisation_id WITH =,
        daterange(effective_from, effective_to, '[)') WITH &&
    )
);

CREATE UNIQUE INDEX uq_dim_organisation_current ON analytics.dim_organisation(source_organisation_id) WHERE is_current = true;

CREATE TABLE analytics.dim_gig_worker (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    source_gig_worker_id bigint NOT NULL,
    worker_pseudonym bytea NOT NULL,
    service_category_name varchar(100) NOT NULL,
    hourly_rate_band varchar(50) NOT NULL,
    availability_band varchar(50) NOT NULL,
    rating_band varchar(50) NOT NULL,
    effective_from date NOT NULL,
    effective_to date NULL,
    is_current boolean GENERATED ALWAYS AS (effective_to IS NULL) STORED,
    CONSTRAINT ck_dim_gig_worker_period CHECK (effective_to IS NULL OR effective_to > effective_from),
    CONSTRAINT ex_dim_gig_worker_period EXCLUDE USING gist (
        source_gig_worker_id WITH =,
        daterange(effective_from, effective_to, '[)') WITH &&
    )
);

CREATE UNIQUE INDEX uq_dim_gig_worker_current ON analytics.dim_gig_worker(source_gig_worker_id) WHERE is_current = true;

CREATE TABLE analytics.dim_subscription_plan (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    source_subscription_plan_id bigint NOT NULL,
    plan_family_code varchar(50) NOT NULL,
    billing_interval_code varchar(50) NOT NULL,
    tier_name varchar(50) NOT NULL,
    effective_from date NOT NULL,
    effective_to date NULL,
    is_current boolean GENERATED ALWAYS AS (effective_to IS NULL) STORED,
    CONSTRAINT ck_dim_subscription_plan_period CHECK (effective_to IS NULL OR effective_to > effective_from),
    CONSTRAINT ex_dim_subscription_plan_period EXCLUDE USING gist (
        source_subscription_plan_id WITH =,
        daterange(effective_from, effective_to, '[)') WITH &&
    )
);

CREATE UNIQUE INDEX uq_dim_subscription_plan_current ON analytics.dim_subscription_plan(source_subscription_plan_id) WHERE is_current = true;

CREATE TABLE analytics.dim_licence (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    source_licence_id bigint NOT NULL,
    plan_family_code varchar(50) NOT NULL,
    max_seats integer NOT NULL DEFAULT 1,
    max_devices_per_user integer NOT NULL DEFAULT 3,
    effective_from date NOT NULL,
    effective_to date NULL,
    is_current boolean GENERATED ALWAYS AS (effective_to IS NULL) STORED,
    CONSTRAINT ck_dim_licence_period CHECK (effective_to IS NULL OR effective_to > effective_from),
    CONSTRAINT ex_dim_licence_period EXCLUDE USING gist (
        source_licence_id WITH =,
        daterange(effective_from, effective_to, '[)') WITH &&
    )
);

CREATE UNIQUE INDEX uq_dim_licence_current ON analytics.dim_licence(source_licence_id) WHERE is_current = true;

-- ============================================================================
-- 3. STAR SCHEMA FACT TABLES (16 Facts, Monthly Partitioned on date_id)
-- ============================================================================

CREATE TABLE analytics.fact_application_event (
    id bigint GENERATED ALWAYS AS IDENTITY,
    date_id integer NOT NULL REFERENCES analytics.dim_date(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    dim_candidate_id bigint NOT NULL REFERENCES analytics.dim_candidate(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    dim_job_requirement_id bigint NOT NULL REFERENCES analytics.dim_job_requirement(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    dim_organisation_id bigint NOT NULL REFERENCES analytics.dim_organisation(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    dim_application_status_id bigint NOT NULL REFERENCES analytics.dim_application_status(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    previous_dim_application_status_id bigint NULL REFERENCES analytics.dim_application_status(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    seconds_in_previous_status integer NULL CHECK (seconds_in_previous_status >= 0),
    event_count smallint NOT NULL DEFAULT 1 CHECK (event_count = 1),
    source_system_code varchar(50) NOT NULL,
    source_event_id bigint NOT NULL,
    load_batch_id bigint NOT NULL REFERENCES analytics.load_batch(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    PRIMARY KEY (id, date_id),
    CONSTRAINT uq_fact_application_event_source UNIQUE (source_system_code, source_event_id, date_id)
) PARTITION BY RANGE (date_id);

CREATE TABLE analytics.fact_application_pipeline_snapshot (
    id bigint GENERATED ALWAYS AS IDENTITY,
    date_id integer NOT NULL REFERENCES analytics.dim_date(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    dim_job_requirement_id bigint NOT NULL REFERENCES analytics.dim_job_requirement(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    dim_organisation_id bigint NOT NULL REFERENCES analytics.dim_organisation(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    dim_location_id bigint NOT NULL REFERENCES analytics.dim_location(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    dim_application_status_id bigint NOT NULL REFERENCES analytics.dim_application_status(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    application_count integer NOT NULL CHECK (application_count >= 0),
    load_batch_id bigint NOT NULL REFERENCES analytics.load_batch(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    PRIMARY KEY (id, date_id),
    CONSTRAINT uq_fact_pipeline_snapshot_grain UNIQUE (date_id, dim_job_requirement_id, dim_application_status_id)
) PARTITION BY RANGE (date_id);

CREATE TABLE analytics.fact_job_snapshot (
    id bigint GENERATED ALWAYS AS IDENTITY,
    date_id integer NOT NULL REFERENCES analytics.dim_date(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    dim_job_requirement_id bigint NOT NULL REFERENCES analytics.dim_job_requirement(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    dim_organisation_id bigint NOT NULL REFERENCES analytics.dim_organisation(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    dim_location_id bigint NOT NULL REFERENCES analytics.dim_location(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    dim_job_status_id bigint NOT NULL REFERENCES analytics.dim_job_status(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    open_positions integer NOT NULL CHECK (open_positions >= 0),
    is_published boolean NOT NULL,
    load_batch_id bigint NOT NULL REFERENCES analytics.load_batch(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    PRIMARY KEY (id, date_id),
    CONSTRAINT uq_fact_job_snapshot_grain UNIQUE (date_id, dim_job_requirement_id)
) PARTITION BY RANGE (date_id);

CREATE TABLE analytics.fact_candidate_activity (
    id bigint GENERATED ALWAYS AS IDENTITY,
    date_id integer NOT NULL REFERENCES analytics.dim_date(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    dim_candidate_id bigint NOT NULL REFERENCES analytics.dim_candidate(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    dim_user_id bigint NOT NULL REFERENCES analytics.dim_user(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    dim_channel_id bigint NOT NULL REFERENCES analytics.dim_channel(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    event_count smallint NOT NULL DEFAULT 1 CHECK (event_count = 1),
    activity_type varchar(50) NOT NULL,
    source_system_code varchar(50) NOT NULL,
    source_event_id bigint NOT NULL,
    load_batch_id bigint NOT NULL REFERENCES analytics.load_batch(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    PRIMARY KEY (id, date_id),
    CONSTRAINT uq_fact_candidate_activity_source UNIQUE (source_system_code, source_event_id, date_id)
) PARTITION BY RANGE (date_id);

CREATE TABLE analytics.fact_profile_view (
    id bigint GENERATED ALWAYS AS IDENTITY,
    date_id integer NOT NULL REFERENCES analytics.dim_date(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    dim_candidate_id bigint NOT NULL REFERENCES analytics.dim_candidate(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    dim_user_id bigint NOT NULL REFERENCES analytics.dim_user(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    dim_organisation_id bigint NOT NULL REFERENCES analytics.dim_organisation(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    view_count integer NOT NULL DEFAULT 1 CHECK (view_count = 1),
    source_system_code varchar(50) NOT NULL,
    source_event_id bigint NOT NULL,
    load_batch_id bigint NOT NULL REFERENCES analytics.load_batch(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    PRIMARY KEY (id, date_id),
    CONSTRAINT uq_fact_profile_view_source UNIQUE (source_system_code, source_event_id, date_id)
) PARTITION BY RANGE (date_id);

CREATE TABLE analytics.fact_profile_download (
    id bigint GENERATED ALWAYS AS IDENTITY,
    date_id integer NOT NULL REFERENCES analytics.dim_date(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    dim_candidate_id bigint NOT NULL REFERENCES analytics.dim_candidate(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    dim_user_id bigint NOT NULL REFERENCES analytics.dim_user(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    dim_organisation_id bigint NOT NULL REFERENCES analytics.dim_organisation(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    dim_credit_event_type_id bigint NOT NULL REFERENCES analytics.dim_credit_event_type(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    credits_spent integer NOT NULL CHECK (credits_spent >= 0),
    download_count integer NOT NULL DEFAULT 1 CHECK (download_count = 1),
    source_system_code varchar(50) NOT NULL,
    source_event_id bigint NOT NULL,
    load_batch_id bigint NOT NULL REFERENCES analytics.load_batch(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    PRIMARY KEY (id, date_id),
    CONSTRAINT uq_fact_profile_download_source UNIQUE (source_system_code, source_event_id, date_id)
) PARTITION BY RANGE (date_id);

CREATE TABLE analytics.fact_sourcing_activity (
    id bigint GENERATED ALWAYS AS IDENTITY,
    date_id integer NOT NULL REFERENCES analytics.dim_date(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    dim_job_requirement_id bigint NOT NULL REFERENCES analytics.dim_job_requirement(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    dim_organisation_id bigint NOT NULL REFERENCES analytics.dim_organisation(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    dim_user_id bigint NOT NULL REFERENCES analytics.dim_user(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    dim_channel_id bigint NOT NULL REFERENCES analytics.dim_channel(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    recipient_count integer NOT NULL CHECK (recipient_count >= 0),
    response_count integer NOT NULL CHECK (response_count >= 0),
    shortlist_count integer NOT NULL CHECK (shortlist_count >= 0),
    source_system_code varchar(50) NOT NULL,
    source_event_id bigint NOT NULL,
    load_batch_id bigint NOT NULL REFERENCES analytics.load_batch(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    PRIMARY KEY (id, date_id),
    CONSTRAINT uq_fact_sourcing_activity_source UNIQUE (source_system_code, source_event_id, date_id)
) PARTITION BY RANGE (date_id);

CREATE TABLE analytics.fact_gig_application_event (
    id bigint GENERATED ALWAYS AS IDENTITY,
    date_id integer NOT NULL REFERENCES analytics.dim_date(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    dim_gig_worker_id bigint NOT NULL REFERENCES analytics.dim_gig_worker(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    dim_job_category_id bigint NOT NULL REFERENCES analytics.dim_job_category(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    dim_organisation_id bigint NOT NULL REFERENCES analytics.dim_organisation(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    dim_location_id bigint NOT NULL REFERENCES analytics.dim_location(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    dim_application_status_id bigint NOT NULL REFERENCES analytics.dim_application_status(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    seconds_in_previous_status integer NULL CHECK (seconds_in_previous_status >= 0),
    event_count smallint NOT NULL DEFAULT 1 CHECK (event_count = 1),
    source_system_code varchar(50) NOT NULL,
    source_event_id bigint NOT NULL,
    load_batch_id bigint NOT NULL REFERENCES analytics.load_batch(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    PRIMARY KEY (id, date_id),
    CONSTRAINT uq_fact_gig_app_event_source UNIQUE (source_system_code, source_event_id, date_id)
) PARTITION BY RANGE (date_id);

CREATE TABLE analytics.fact_gig_assignment (
    id bigint GENERATED ALWAYS AS IDENTITY,
    date_id integer NOT NULL REFERENCES analytics.dim_date(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    dim_gig_worker_id bigint NOT NULL REFERENCES analytics.dim_gig_worker(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    dim_job_category_id bigint NOT NULL REFERENCES analytics.dim_job_category(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    dim_organisation_id bigint NOT NULL REFERENCES analytics.dim_organisation(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    dim_location_id bigint NOT NULL REFERENCES analytics.dim_location(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    dim_currency_id bigint NOT NULL REFERENCES analytics.dim_currency(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    agreed_price numeric(14,2) NOT NULL CHECK (agreed_price >= 0),
    reconciled_earnings numeric(14,2) NOT NULL DEFAULT 0 CHECK (reconciled_earnings >= 0),
    rating_score numeric(3,2) NULL CHECK (rating_score BETWEEN 1.0 AND 5.0),
    source_system_code varchar(50) NOT NULL,
    source_event_id bigint NOT NULL,
    load_batch_id bigint NOT NULL REFERENCES analytics.load_batch(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    PRIMARY KEY (id, date_id),
    CONSTRAINT uq_fact_gig_assignment_source UNIQUE (source_system_code, source_event_id, date_id)
) PARTITION BY RANGE (date_id);

CREATE TABLE analytics.fact_subscription_event (
    id bigint GENERATED ALWAYS AS IDENTITY,
    date_id integer NOT NULL REFERENCES analytics.dim_date(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    dim_organisation_id bigint NOT NULL REFERENCES analytics.dim_organisation(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    dim_subscription_plan_id bigint NOT NULL REFERENCES analytics.dim_subscription_plan(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    dim_licence_id bigint NOT NULL REFERENCES analytics.dim_licence(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    event_count smallint NOT NULL DEFAULT 1 CHECK (event_count = 1),
    period_days integer NOT NULL CHECK (period_days >= 0),
    source_system_code varchar(50) NOT NULL,
    source_event_id bigint NOT NULL,
    load_batch_id bigint NOT NULL REFERENCES analytics.load_batch(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    PRIMARY KEY (id, date_id),
    CONSTRAINT uq_fact_subscription_event_source UNIQUE (source_system_code, source_event_id, date_id)
) PARTITION BY RANGE (date_id);

CREATE TABLE analytics.fact_payment_transaction (
    id bigint GENERATED ALWAYS AS IDENTITY,
    date_id integer NOT NULL REFERENCES analytics.dim_date(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    dim_organisation_id bigint NOT NULL REFERENCES analytics.dim_organisation(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    dim_subscription_plan_id bigint NULL REFERENCES analytics.dim_subscription_plan(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    dim_currency_id bigint NOT NULL REFERENCES analytics.dim_currency(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    amount numeric(14,2) NOT NULL,
    source_system_code varchar(50) NOT NULL,
    source_event_id bigint NOT NULL,
    load_batch_id bigint NOT NULL REFERENCES analytics.load_batch(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    PRIMARY KEY (id, date_id),
    CONSTRAINT uq_fact_payment_transaction_source UNIQUE (source_system_code, source_event_id, date_id)
) PARTITION BY RANGE (date_id);

CREATE TABLE analytics.fact_wallet_transaction (
    id bigint GENERATED ALWAYS AS IDENTITY,
    date_id integer NOT NULL REFERENCES analytics.dim_date(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    dim_organisation_id bigint NOT NULL REFERENCES analytics.dim_organisation(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    dim_user_id bigint NOT NULL REFERENCES analytics.dim_user(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    dim_credit_event_type_id bigint NOT NULL REFERENCES analytics.dim_credit_event_type(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    credit_delta integer NOT NULL, -- Signed (+recharge, -consume)
    source_system_code varchar(50) NOT NULL,
    source_event_id bigint NOT NULL,
    load_batch_id bigint NOT NULL REFERENCES analytics.load_batch(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    PRIMARY KEY (id, date_id),
    CONSTRAINT uq_fact_wallet_transaction_source UNIQUE (source_system_code, source_event_id, date_id)
) PARTITION BY RANGE (date_id);

CREATE TABLE analytics.fact_licence_utilisation_snapshot (
    id bigint GENERATED ALWAYS AS IDENTITY,
    date_id integer NOT NULL REFERENCES analytics.dim_date(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    dim_licence_id bigint NOT NULL REFERENCES analytics.dim_licence(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    dim_organisation_id bigint NOT NULL REFERENCES analytics.dim_organisation(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    seats_used integer NOT NULL CHECK (seats_used >= 0),
    seats_allowed integer NOT NULL CHECK (seats_allowed >= 0),
    active_sessions integer NOT NULL CHECK (active_sessions >= 0),
    device_limit_hits integer NOT NULL DEFAULT 0 CHECK (device_limit_hits >= 0),
    load_batch_id bigint NOT NULL REFERENCES analytics.load_batch(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    PRIMARY KEY (id, date_id),
    CONSTRAINT uq_fact_licence_utilisation_grain UNIQUE (date_id, dim_licence_id)
) PARTITION BY RANGE (date_id);

CREATE TABLE analytics.fact_notification_delivery (
    id bigint GENERATED ALWAYS AS IDENTITY,
    date_id integer NOT NULL REFERENCES analytics.dim_date(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    dim_user_id bigint NOT NULL REFERENCES analytics.dim_user(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    dim_channel_id bigint NOT NULL REFERENCES analytics.dim_channel(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    dim_notification_type_id bigint NOT NULL REFERENCES analytics.dim_notification_type(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    dim_language_id bigint NOT NULL REFERENCES analytics.dim_language(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    attempt_count smallint NOT NULL CHECK (attempt_count >= 1),
    is_delivered boolean NOT NULL,
    is_read boolean NOT NULL DEFAULT false,
    is_clicked boolean NOT NULL DEFAULT false,
    seconds_to_deliver integer NULL CHECK (seconds_to_deliver >= 0),
    source_system_code varchar(50) NOT NULL,
    source_event_id bigint NOT NULL,
    load_batch_id bigint NOT NULL REFERENCES analytics.load_batch(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    PRIMARY KEY (id, date_id),
    CONSTRAINT uq_fact_notification_delivery_source UNIQUE (source_system_code, source_event_id, date_id)
) PARTITION BY RANGE (date_id);

CREATE TABLE analytics.fact_support_ticket (
    id bigint GENERATED ALWAYS AS IDENTITY,
    date_id integer NOT NULL REFERENCES analytics.dim_date(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    dim_user_id bigint NOT NULL REFERENCES analytics.dim_user(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    dim_organisation_id bigint NULL REFERENCES analytics.dim_organisation(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    dim_support_category_id bigint NOT NULL REFERENCES analytics.dim_support_category(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    seconds_to_first_response integer NULL CHECK (seconds_to_first_response >= 0),
    seconds_to_resolve integer NULL CHECK (seconds_to_resolve >= 0),
    reopen_count smallint NOT NULL DEFAULT 0 CHECK (reopen_count >= 0),
    source_system_code varchar(50) NOT NULL,
    source_event_id bigint NOT NULL,
    load_batch_id bigint NOT NULL REFERENCES analytics.load_batch(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    PRIMARY KEY (id, date_id),
    CONSTRAINT uq_fact_support_ticket_source UNIQUE (source_system_code, source_event_id, date_id)
) PARTITION BY RANGE (date_id);

CREATE TABLE analytics.fact_referral_event (
    id bigint GENERATED ALWAYS AS IDENTITY,
    date_id integer NOT NULL REFERENCES analytics.dim_date(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    dim_user_id bigint NOT NULL REFERENCES analytics.dim_user(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    dim_channel_id bigint NOT NULL REFERENCES analytics.dim_channel(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    event_count smallint NOT NULL DEFAULT 1 CHECK (event_count = 1),
    reward_credits integer NOT NULL DEFAULT 0 CHECK (reward_credits >= 0),
    source_system_code varchar(50) NOT NULL,
    source_event_id bigint NOT NULL,
    load_batch_id bigint NOT NULL REFERENCES analytics.load_batch(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    PRIMARY KEY (id, date_id),
    CONSTRAINT uq_fact_referral_event_source UNIQUE (source_system_code, source_event_id, date_id)
) PARTITION BY RANGE (date_id);

-- Provision Active Partitions for all 16 Facts (202610, 202611, future)
CREATE TABLE analytics.fact_application_event_p202610 PARTITION OF analytics.fact_application_event FOR VALUES FROM (20261001) TO (20261101);
CREATE TABLE analytics.fact_application_pipeline_snapshot_p202610 PARTITION OF analytics.fact_application_pipeline_snapshot FOR VALUES FROM (20261001) TO (20261101);
CREATE TABLE analytics.fact_job_snapshot_p202610 PARTITION OF analytics.fact_job_snapshot FOR VALUES FROM (20261001) TO (20261101);
CREATE TABLE analytics.fact_candidate_activity_p202610 PARTITION OF analytics.fact_candidate_activity FOR VALUES FROM (20261001) TO (20261101);
CREATE TABLE analytics.fact_profile_view_p202610 PARTITION OF analytics.fact_profile_view FOR VALUES FROM (20261001) TO (20261101);
CREATE TABLE analytics.fact_profile_download_p202610 PARTITION OF analytics.fact_profile_download FOR VALUES FROM (20261001) TO (20261101);
CREATE TABLE analytics.fact_sourcing_activity_p202610 PARTITION OF analytics.fact_sourcing_activity FOR VALUES FROM (20261001) TO (20261101);
CREATE TABLE analytics.fact_gig_application_event_p202610 PARTITION OF analytics.fact_gig_application_event FOR VALUES FROM (20261001) TO (20261101);
CREATE TABLE analytics.fact_gig_assignment_p202610 PARTITION OF analytics.fact_gig_assignment FOR VALUES FROM (20261001) TO (20261101);
CREATE TABLE analytics.fact_subscription_event_p202610 PARTITION OF analytics.fact_subscription_event FOR VALUES FROM (20261001) TO (20261101);
CREATE TABLE analytics.fact_payment_transaction_p202610 PARTITION OF analytics.fact_payment_transaction FOR VALUES FROM (20261001) TO (20261101);
CREATE TABLE analytics.fact_wallet_transaction_p202610 PARTITION OF analytics.fact_wallet_transaction FOR VALUES FROM (20261001) TO (20261101);
CREATE TABLE analytics.fact_licence_utilisation_snapshot_p202610 PARTITION OF analytics.fact_licence_utilisation_snapshot FOR VALUES FROM (20261001) TO (20261101);
CREATE TABLE analytics.fact_notification_delivery_p202610 PARTITION OF analytics.fact_notification_delivery FOR VALUES FROM (20261001) TO (20261101);
CREATE TABLE analytics.fact_support_ticket_p202610 PARTITION OF analytics.fact_support_ticket FOR VALUES FROM (20261001) TO (20261101);
CREATE TABLE analytics.fact_referral_event_p202610 PARTITION OF analytics.fact_referral_event FOR VALUES FROM (20261001) TO (20261101);

-- Default / future partition catch-all
CREATE TABLE analytics.fact_application_event_p_future PARTITION OF analytics.fact_application_event FOR VALUES FROM (20261101) TO (20300101);
CREATE TABLE analytics.fact_application_pipeline_snapshot_p_future PARTITION OF analytics.fact_application_pipeline_snapshot FOR VALUES FROM (20261101) TO (20300101);
CREATE TABLE analytics.fact_job_snapshot_p_future PARTITION OF analytics.fact_job_snapshot FOR VALUES FROM (20261101) TO (20300101);
CREATE TABLE analytics.fact_candidate_activity_p_future PARTITION OF analytics.fact_candidate_activity FOR VALUES FROM (20261101) TO (20300101);
CREATE TABLE analytics.fact_profile_view_p_future PARTITION OF analytics.fact_profile_view FOR VALUES FROM (20261101) TO (20300101);
CREATE TABLE analytics.fact_profile_download_p_future PARTITION OF analytics.fact_profile_download FOR VALUES FROM (20261101) TO (20300101);
CREATE TABLE analytics.fact_sourcing_activity_p_future PARTITION OF analytics.fact_sourcing_activity FOR VALUES FROM (20261101) TO (20300101);
CREATE TABLE analytics.fact_gig_application_event_p_future PARTITION OF analytics.fact_gig_application_event FOR VALUES FROM (20261101) TO (20300101);
CREATE TABLE analytics.fact_gig_assignment_p_future PARTITION OF analytics.fact_gig_assignment FOR VALUES FROM (20261101) TO (20300101);
CREATE TABLE analytics.fact_subscription_event_p_future PARTITION OF analytics.fact_subscription_event FOR VALUES FROM (20261101) TO (20300101);
CREATE TABLE analytics.fact_payment_transaction_p_future PARTITION OF analytics.fact_payment_transaction FOR VALUES FROM (20261101) TO (20300101);
CREATE TABLE analytics.fact_wallet_transaction_p_future PARTITION OF analytics.fact_wallet_transaction FOR VALUES FROM (20261101) TO (20300101);
CREATE TABLE analytics.fact_licence_utilisation_snapshot_p_future PARTITION OF analytics.fact_licence_utilisation_snapshot FOR VALUES FROM (20261101) TO (20300101);
CREATE TABLE analytics.fact_notification_delivery_p_future PARTITION OF analytics.fact_notification_delivery FOR VALUES FROM (20261101) TO (20300101);
CREATE TABLE analytics.fact_support_ticket_p_future PARTITION OF analytics.fact_support_ticket FOR VALUES FROM (20261101) TO (20300101);
CREATE TABLE analytics.fact_referral_event_p_future PARTITION OF analytics.fact_referral_event FOR VALUES FROM (20261101) TO (20300101);

-- ============================================================================
-- 4. AGGREGATE TABLES (9 Reporting Marts with Upsert Rules)
-- ============================================================================

CREATE TABLE analytics.agg_daily_hiring_kpi (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    date_id integer NOT NULL REFERENCES analytics.dim_date(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    dim_location_id bigint NOT NULL REFERENCES analytics.dim_location(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    dim_job_category_id bigint NOT NULL REFERENCES analytics.dim_job_category(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    total_applications integer NOT NULL DEFAULT 0,
    total_interviews integer NOT NULL DEFAULT 0,
    total_offers integer NOT NULL DEFAULT 0,
    total_hires integer NOT NULL DEFAULT 0,
    CONSTRAINT uq_agg_daily_hiring_grain UNIQUE (date_id, dim_location_id, dim_job_category_id)
);

CREATE TABLE analytics.agg_daily_candidate_activity (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    date_id integer NOT NULL REFERENCES analytics.dim_date(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    activity_type varchar(50) NOT NULL,
    candidate_cohort varchar(50) NOT NULL,
    active_candidates integer NOT NULL DEFAULT 0,
    event_volume bigint NOT NULL DEFAULT 0,
    CONSTRAINT uq_agg_daily_candidate_grain UNIQUE (date_id, activity_type, candidate_cohort)
);

CREATE TABLE analytics.agg_daily_sourcing_kpi (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    date_id integer NOT NULL REFERENCES analytics.dim_date(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    dim_organisation_id bigint NOT NULL REFERENCES analytics.dim_organisation(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    dim_channel_id bigint NOT NULL REFERENCES analytics.dim_channel(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    outreach_sent integer NOT NULL DEFAULT 0,
    outreach_responded integer NOT NULL DEFAULT 0,
    shortlists_generated integer NOT NULL DEFAULT 0,
    CONSTRAINT uq_agg_daily_sourcing_grain UNIQUE (date_id, dim_organisation_id, dim_channel_id)
);

CREATE TABLE analytics.agg_daily_revenue_kpi (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    date_id integer NOT NULL REFERENCES analytics.dim_date(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    plan_cohort varchar(50) NOT NULL,
    dim_currency_id bigint NOT NULL REFERENCES analytics.dim_currency(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    gross_payment_amount numeric(14,2) NOT NULL DEFAULT 0.00,
    refund_amount numeric(14,2) NOT NULL DEFAULT 0.00,
    net_revenue_amount numeric(14,2) NOT NULL DEFAULT 0.00,
    CONSTRAINT uq_agg_daily_revenue_grain UNIQUE (date_id, plan_cohort, dim_currency_id)
);

CREATE TABLE analytics.agg_daily_notification_kpi (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    date_id integer NOT NULL REFERENCES analytics.dim_date(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    dim_channel_id bigint NOT NULL REFERENCES analytics.dim_channel(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    dim_notification_type_id bigint NOT NULL REFERENCES analytics.dim_notification_type(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    attempts_count integer NOT NULL DEFAULT 0,
    delivered_count integer NOT NULL DEFAULT 0,
    failed_count integer NOT NULL DEFAULT 0,
    opened_count integer NOT NULL DEFAULT 0,
    clicked_count integer NOT NULL DEFAULT 0,
    CONSTRAINT uq_agg_daily_notification_grain UNIQUE (date_id, dim_channel_id, dim_notification_type_id)
);

CREATE TABLE analytics.agg_daily_gig_kpi (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    date_id integer NOT NULL REFERENCES analytics.dim_date(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    dim_job_category_id bigint NOT NULL REFERENCES analytics.dim_job_category(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    dim_location_id bigint NOT NULL REFERENCES analytics.dim_location(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    applications_count integer NOT NULL DEFAULT 0,
    acceptances_count integer NOT NULL DEFAULT 0,
    completed_gigs_count integer NOT NULL DEFAULT 0,
    total_reconciled_earnings numeric(14,2) NOT NULL DEFAULT 0.00,
    average_rating_score numeric(3,2) NULL,
    CONSTRAINT uq_agg_daily_gig_grain UNIQUE (date_id, dim_job_category_id, dim_location_id)
);

CREATE TABLE analytics.agg_daily_wallet_kpi (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    date_id integer NOT NULL REFERENCES analytics.dim_date(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    dim_credit_event_type_id bigint NOT NULL REFERENCES analytics.dim_credit_event_type(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    organisation_cohort varchar(50) NOT NULL,
    credits_recharged bigint NOT NULL DEFAULT 0,
    credits_consumed bigint NOT NULL DEFAULT 0,
    CONSTRAINT uq_agg_daily_wallet_grain UNIQUE (date_id, dim_credit_event_type_id, organisation_cohort)
);

CREATE TABLE analytics.agg_daily_support_kpi (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    date_id integer NOT NULL REFERENCES analytics.dim_date(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    dim_support_category_id bigint NOT NULL REFERENCES analytics.dim_support_category(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    ticket_priority_code varchar(50) NOT NULL,
    tickets_opened integer NOT NULL DEFAULT 0,
    tickets_closed integer NOT NULL DEFAULT 0,
    median_resolve_seconds integer NULL,
    CONSTRAINT uq_agg_daily_support_grain UNIQUE (date_id, dim_support_category_id, ticket_priority_code)
);

CREATE TABLE analytics.agg_weekly_candidate_retention (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    registration_week_date date NOT NULL,
    weeks_since_registration smallint NOT NULL CHECK (weeks_since_registration >= 0),
    active_candidates integer NOT NULL DEFAULT 0,
    retained_share_percent numeric(5,2) NOT NULL CHECK (retained_share_percent BETWEEN 0.00 AND 100.00),
    CONSTRAINT uq_agg_candidate_retention_grain UNIQUE (registration_week_date, weeks_since_registration)
);

-- ============================================================================
-- 5. ANALYTICS EXPORT VIEWS & PRIVACY GUARDS (Small-Cell Rule < 10)
-- ============================================================================

CREATE OR REPLACE VIEW analytics.v_executive_weekly_retention_export AS
SELECT 
    registration_week_date,
    weeks_since_registration,
    CASE WHEN active_candidates < 10 THEN NULL ELSE active_candidates END AS active_candidates_masked,
    retained_share_percent
FROM analytics.agg_weekly_candidate_retention;

COMMIT;
