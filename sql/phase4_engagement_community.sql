-- ============================================================================
-- Talentra Enterprise Database Architecture
-- Phase 4 - Module A: Notifications, Preferences & Community (engagement)
-- PostgreSQL 16+
--
-- Conforming to:
-- - Talentra Phase 4: Entities and Relationships Specification (Module A)
-- - Talentra Phase 4: Gap Analysis and Revised Schema (Gaps A01 - A16, G01 - G11)
--
-- Scope:
-- 1. 19 Lookup Tables (Rule Group 3 Standard Pattern)
-- 2. 38 Core Entities across 5 Sub-Domains:
--    a. Notifications & Delivery Pipeline (High-volume partitioned delivery & attempts)
--    b. User Preferences & Search Criteria (Structured criteria, job alerts, saved searches)
--    c. Follow Graph & Community (Typed targets, topics, posts, comments, reactions, moderation)
--    d. Support Ticketing & Multilingual FAQs (SLA fields, status history, attachments)
--    e. Growth, Referrals & Social Sharing (Referral codes, events, wallet reward linkage)
-- 3. Invariants & Triggers:
--    - can_deliver() notification gate (consent, preference, suppression, quiet hours)
--    - Typed target nonnull guards (follow_relation, community_report, community_moderation_action)
--    - Append-only immutability triggers (deliveries, attempts, logs, status history)
--    - Row-Level Security Policies and Filtered Active Views
-- ============================================================================

\set ON_ERROR_STOP on

BEGIN;

CREATE EXTENSION IF NOT EXISTS btree_gist;
CREATE EXTENSION IF NOT EXISTS pg_trgm;

CREATE SCHEMA IF NOT EXISTS engagement;

-- ============================================================================
-- 1. LOOKUP TABLES (19 Lookups conforming to Rule Group 3)
-- ============================================================================

CREATE TABLE engagement.notification_type (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    code varchar(50) NOT NULL,
    label_key varchar(150) NOT NULL,
    is_mandatory boolean NOT NULL DEFAULT false,
    is_active boolean NOT NULL DEFAULT true,
    sort_order integer NOT NULL DEFAULT 0,
    created_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by bigint NOT NULL REFERENCES administration.user_account(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    updated_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by bigint NOT NULL REFERENCES administration.user_account(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    CONSTRAINT uq_notification_type_code UNIQUE (code),
    CONSTRAINT ck_notification_type_code CHECK (code = lower(code) AND code ~ '^[a-z][a-z0-9_]*$')
);

CREATE TABLE engagement.notification_channel (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    code varchar(50) NOT NULL,
    label_key varchar(150) NOT NULL,
    is_active boolean NOT NULL DEFAULT true,
    sort_order integer NOT NULL DEFAULT 0,
    created_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by bigint NOT NULL REFERENCES administration.user_account(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    updated_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by bigint NOT NULL REFERENCES administration.user_account(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    CONSTRAINT uq_notification_channel_code UNIQUE (code),
    CONSTRAINT ck_notification_channel_code CHECK (code = lower(code) AND code ~ '^[a-z][a-z0-9_]*$')
);

CREATE TABLE engagement.notification_delivery_status (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    code varchar(50) NOT NULL,
    label_key varchar(150) NOT NULL,
    is_active boolean NOT NULL DEFAULT true,
    sort_order integer NOT NULL DEFAULT 0,
    created_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by bigint NOT NULL REFERENCES administration.user_account(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    updated_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by bigint NOT NULL REFERENCES administration.user_account(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    CONSTRAINT uq_notification_delivery_status_code UNIQUE (code),
    CONSTRAINT ck_notification_delivery_status_code CHECK (code = lower(code) AND code ~ '^[a-z][a-z0-9_]*$')
);

CREATE TABLE engagement.notification_delivery_outcome (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    code varchar(50) NOT NULL,
    label_key varchar(150) NOT NULL,
    is_active boolean NOT NULL DEFAULT true,
    sort_order integer NOT NULL DEFAULT 0,
    created_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by bigint NOT NULL REFERENCES administration.user_account(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    updated_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by bigint NOT NULL REFERENCES administration.user_account(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    CONSTRAINT uq_notification_delivery_outcome_code UNIQUE (code),
    CONSTRAINT ck_notification_delivery_outcome_code CHECK (code = lower(code) AND code ~ '^[a-z][a-z0-9_]*$')
);

CREATE TABLE engagement.notification_provider (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    code varchar(50) NOT NULL,
    label_key varchar(150) NOT NULL,
    is_degraded boolean NOT NULL DEFAULT false,
    is_active boolean NOT NULL DEFAULT true,
    sort_order integer NOT NULL DEFAULT 0,
    created_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by bigint NOT NULL REFERENCES administration.user_account(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    updated_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by bigint NOT NULL REFERENCES administration.user_account(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    CONSTRAINT uq_notification_provider_code UNIQUE (code),
    CONSTRAINT ck_notification_provider_code CHECK (code = lower(code) AND code ~ '^[a-z][a-z0-9_]*$')
);

CREATE TABLE engagement.alert_frequency (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    code varchar(50) NOT NULL,
    label_key varchar(150) NOT NULL,
    is_active boolean NOT NULL DEFAULT true,
    sort_order integer NOT NULL DEFAULT 0,
    created_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by bigint NOT NULL REFERENCES administration.user_account(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    updated_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by bigint NOT NULL REFERENCES administration.user_account(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    CONSTRAINT uq_alert_frequency_code UNIQUE (code),
    CONSTRAINT ck_alert_frequency_code CHECK (code = lower(code) AND code ~ '^[a-z][a-z0-9_]*$')
);

CREATE TABLE engagement.visibility_level (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    code varchar(50) NOT NULL,
    label_key varchar(150) NOT NULL,
    is_active boolean NOT NULL DEFAULT true,
    sort_order integer NOT NULL DEFAULT 0,
    created_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by bigint NOT NULL REFERENCES administration.user_account(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    updated_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by bigint NOT NULL REFERENCES administration.user_account(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    CONSTRAINT uq_visibility_level_code UNIQUE (code),
    CONSTRAINT ck_visibility_level_code CHECK (code = lower(code) AND code ~ '^[a-z][a-z0-9_]*$')
);

CREATE TABLE engagement.open_to_work_status (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    code varchar(50) NOT NULL,
    label_key varchar(150) NOT NULL,
    is_active boolean NOT NULL DEFAULT true,
    sort_order integer NOT NULL DEFAULT 0,
    created_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by bigint NOT NULL REFERENCES administration.user_account(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    updated_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by bigint NOT NULL REFERENCES administration.user_account(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    CONSTRAINT uq_open_to_work_status_code UNIQUE (code),
    CONSTRAINT ck_open_to_work_status_code CHECK (code = lower(code) AND code ~ '^[a-z][a-z0-9_]*$')
);

CREATE TABLE engagement.reaction_type (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    code varchar(50) NOT NULL,
    label_key varchar(150) NOT NULL,
    is_active boolean NOT NULL DEFAULT true,
    sort_order integer NOT NULL DEFAULT 0,
    created_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by bigint NOT NULL REFERENCES administration.user_account(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    updated_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by bigint NOT NULL REFERENCES administration.user_account(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    CONSTRAINT uq_reaction_type_code UNIQUE (code),
    CONSTRAINT ck_reaction_type_code CHECK (code = lower(code) AND code ~ '^[a-z][a-z0-9_]*$')
);

CREATE TABLE engagement.moderation_status (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    code varchar(50) NOT NULL,
    label_key varchar(150) NOT NULL,
    is_active boolean NOT NULL DEFAULT true,
    sort_order integer NOT NULL DEFAULT 0,
    created_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by bigint NOT NULL REFERENCES administration.user_account(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    updated_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by bigint NOT NULL REFERENCES administration.user_account(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    CONSTRAINT uq_moderation_status_code UNIQUE (code),
    CONSTRAINT ck_moderation_status_code CHECK (code = lower(code) AND code ~ '^[a-z][a-z0-9_]*$')
);

CREATE TABLE engagement.moderation_action_type (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    code varchar(50) NOT NULL,
    label_key varchar(150) NOT NULL,
    is_active boolean NOT NULL DEFAULT true,
    sort_order integer NOT NULL DEFAULT 0,
    created_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by bigint NOT NULL REFERENCES administration.user_account(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    updated_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by bigint NOT NULL REFERENCES administration.user_account(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    CONSTRAINT uq_moderation_action_type_code UNIQUE (code),
    CONSTRAINT ck_moderation_action_type_code CHECK (code = lower(code) AND code ~ '^[a-z][a-z0-9_]*$')
);

CREATE TABLE engagement.report_reason (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    code varchar(50) NOT NULL,
    label_key varchar(150) NOT NULL,
    is_active boolean NOT NULL DEFAULT true,
    sort_order integer NOT NULL DEFAULT 0,
    created_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by bigint NOT NULL REFERENCES administration.user_account(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    updated_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by bigint NOT NULL REFERENCES administration.user_account(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    CONSTRAINT uq_report_reason_code UNIQUE (code),
    CONSTRAINT ck_report_reason_code CHECK (code = lower(code) AND code ~ '^[a-z][a-z0-9_]*$')
);

CREATE TABLE engagement.review_status (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    code varchar(50) NOT NULL,
    label_key varchar(150) NOT NULL,
    is_active boolean NOT NULL DEFAULT true,
    sort_order integer NOT NULL DEFAULT 0,
    created_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by bigint NOT NULL REFERENCES administration.user_account(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    updated_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by bigint NOT NULL REFERENCES administration.user_account(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    CONSTRAINT uq_review_status_code UNIQUE (code),
    CONSTRAINT ck_review_status_code CHECK (code = lower(code) AND code ~ '^[a-z][a-z0-9_]*$')
);

CREATE TABLE engagement.ticket_category (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    code varchar(50) NOT NULL,
    label_key varchar(150) NOT NULL,
    is_active boolean NOT NULL DEFAULT true,
    sort_order integer NOT NULL DEFAULT 0,
    created_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by bigint NOT NULL REFERENCES administration.user_account(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    updated_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by bigint NOT NULL REFERENCES administration.user_account(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    CONSTRAINT uq_ticket_category_code UNIQUE (code),
    CONSTRAINT ck_ticket_category_code CHECK (code = lower(code) AND code ~ '^[a-z][a-z0-9_]*$')
);

CREATE TABLE engagement.ticket_status (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    code varchar(50) NOT NULL,
    label_key varchar(150) NOT NULL,
    is_active boolean NOT NULL DEFAULT true,
    sort_order integer NOT NULL DEFAULT 0,
    created_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by bigint NOT NULL REFERENCES administration.user_account(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    updated_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by bigint NOT NULL REFERENCES administration.user_account(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    CONSTRAINT uq_ticket_status_code UNIQUE (code),
    CONSTRAINT ck_ticket_status_code CHECK (code = lower(code) AND code ~ '^[a-z][a-z0-9_]*$')
);

CREATE TABLE engagement.ticket_priority (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    code varchar(50) NOT NULL,
    label_key varchar(150) NOT NULL,
    is_active boolean NOT NULL DEFAULT true,
    sort_order integer NOT NULL DEFAULT 0,
    created_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by bigint NOT NULL REFERENCES administration.user_account(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    updated_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by bigint NOT NULL REFERENCES administration.user_account(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    CONSTRAINT uq_ticket_priority_code UNIQUE (code),
    CONSTRAINT ck_ticket_priority_code CHECK (code = lower(code) AND code ~ '^[a-z][a-z0-9_]*$')
);

CREATE TABLE engagement.faq_category (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    code varchar(50) NOT NULL,
    label_key varchar(150) NOT NULL,
    is_active boolean NOT NULL DEFAULT true,
    sort_order integer NOT NULL DEFAULT 0,
    created_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by bigint NOT NULL REFERENCES administration.user_account(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    updated_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by bigint NOT NULL REFERENCES administration.user_account(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    CONSTRAINT uq_faq_category_code UNIQUE (code),
    CONSTRAINT ck_faq_category_code CHECK (code = lower(code) AND code ~ '^[a-z][a-z0-9_]*$')
);

CREATE TABLE engagement.referral_event_type (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    code varchar(50) NOT NULL,
    label_key varchar(150) NOT NULL,
    is_active boolean NOT NULL DEFAULT true,
    sort_order integer NOT NULL DEFAULT 0,
    created_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by bigint NOT NULL REFERENCES administration.user_account(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    updated_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by bigint NOT NULL REFERENCES administration.user_account(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    CONSTRAINT uq_referral_event_type_code UNIQUE (code),
    CONSTRAINT ck_referral_event_type_code CHECK (code = lower(code) AND code ~ '^[a-z][a-z0-9_]*$')
);

CREATE TABLE engagement.referral_source_channel (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    code varchar(50) NOT NULL,
    label_key varchar(150) NOT NULL,
    is_active boolean NOT NULL DEFAULT true,
    sort_order integer NOT NULL DEFAULT 0,
    created_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by bigint NOT NULL REFERENCES administration.user_account(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    updated_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by bigint NOT NULL REFERENCES administration.user_account(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    CONSTRAINT uq_referral_source_channel_code UNIQUE (code),
    CONSTRAINT ck_referral_source_channel_code CHECK (code = lower(code) AND code ~ '^[a-z][a-z0-9_]*$')
);

-- ============================================================================
-- 2. NOTIFICATIONS & HIGH-VOLUME DELIVERY PIPELINE (Entities 1 to 7)
-- ============================================================================

CREATE TABLE engagement.notification_template (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    notification_type_id bigint NOT NULL REFERENCES engagement.notification_type(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    notification_channel_id bigint NOT NULL REFERENCES engagement.notification_channel(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    subject_label_key varchar(150) NOT NULL,
    is_active boolean NOT NULL DEFAULT true,
    created_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by bigint NOT NULL REFERENCES administration.user_account(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    updated_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by bigint NOT NULL REFERENCES administration.user_account(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    deleted_at timestamptz NULL,
    deleted_by bigint NULL REFERENCES administration.user_account(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    CONSTRAINT uq_notification_template_type_channel UNIQUE (notification_type_id, notification_channel_id)
);

CREATE TABLE engagement.notification_template_translation (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    notification_template_id bigint NOT NULL REFERENCES engagement.notification_template(id) ON UPDATE NO ACTION ON DELETE CASCADE,
    language_id bigint NOT NULL REFERENCES master_data.language(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    subject_text varchar(250) NOT NULL,
    body_text text NOT NULL,
    created_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by bigint NOT NULL REFERENCES administration.user_account(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    updated_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by bigint NOT NULL REFERENCES administration.user_account(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    CONSTRAINT uq_notification_template_trans UNIQUE (notification_template_id, language_id)
);

CREATE TABLE engagement.notification (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    notification_type_id bigint NOT NULL REFERENCES engagement.notification_type(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    notification_template_id bigint NOT NULL REFERENCES engagement.notification_template(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    template_params jsonb NOT NULL DEFAULT '{}'::jsonb,
    source_entity_name varchar(80) NOT NULL,
    source_entity_id bigint NOT NULL,
    created_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by bigint NOT NULL REFERENCES administration.user_account(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    CONSTRAINT ck_notification_template_params_size CHECK (pg_column_size(template_params) <= 4096)
);

CREATE INDEX idx_notification_source ON engagement.notification(source_entity_name, source_entity_id);
CREATE INDEX idx_notification_type ON engagement.notification(notification_type_id);

CREATE TABLE engagement.notification_delivery (
    id bigint GENERATED ALWAYS AS IDENTITY,
    notification_created_at timestamptz NOT NULL,
    notification_id bigint NOT NULL REFERENCES engagement.notification(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    recipient_user_account_id bigint NOT NULL REFERENCES administration.user_account(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    notification_channel_id bigint NOT NULL REFERENCES engagement.notification_channel(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    notification_delivery_status_id bigint NOT NULL REFERENCES engagement.notification_delivery_status(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    is_open boolean NOT NULL DEFAULT true,
    attempt_count smallint NOT NULL DEFAULT 0,
    provider_reference varchar(255) NULL,
    destination_masked varchar(254) NULL,
    scheduled_at timestamptz NOT NULL,
    sent_at timestamptz NULL,
    delivered_at timestamptz NULL,
    failed_at timestamptz NULL,
    read_at timestamptz NULL,
    clicked_at timestamptz NULL,
    created_by bigint NOT NULL REFERENCES administration.user_account(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    PRIMARY KEY (id, notification_created_at),
    CONSTRAINT uq_notification_delivery_recipient UNIQUE (
        notification_id, recipient_user_account_id, notification_channel_id, notification_created_at
    ),
    CONSTRAINT ck_notification_delivery_attempt_count CHECK (attempt_count >= 0),
    CONSTRAINT ck_notification_delivery_sent_order CHECK (sent_at IS NULL OR sent_at >= notification_created_at)
) PARTITION BY RANGE (notification_created_at);

-- Default and active partitions
CREATE TABLE engagement.notification_delivery_p202610 PARTITION OF engagement.notification_delivery
    FOR VALUES FROM ('2026-10-01 00:00:00+00') TO ('2026-11-01 00:00:00+00');
CREATE TABLE engagement.notification_delivery_p202611 PARTITION OF engagement.notification_delivery
    FOR VALUES FROM ('2026-11-01 00:00:00+00') TO ('2026-12-01 00:00:00+00');
CREATE TABLE engagement.notification_delivery_p_future PARTITION OF engagement.notification_delivery
    FOR VALUES FROM ('2026-12-01 00:00:00+00') TO ('2030-01-01 00:00:00+00');

CREATE INDEX idx_notification_delivery_scheduled_open
    ON engagement.notification_delivery (scheduled_at) WHERE is_open = true;
CREATE INDEX idx_notification_delivery_recipient_time
    ON engagement.notification_delivery (recipient_user_account_id, notification_created_at DESC);

CREATE TABLE engagement.notification_delivery_attempt (
    id bigint GENERATED ALWAYS AS IDENTITY,
    notification_delivery_id bigint NOT NULL,
    notification_created_at timestamptz NOT NULL,
    attempt_number smallint NOT NULL,
    notification_provider_id bigint NOT NULL REFERENCES engagement.notification_provider(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    delivery_outcome_id bigint NOT NULL REFERENCES engagement.notification_delivery_outcome(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    error_code varchar(80) NULL,
    attempted_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id, attempted_at),
    CONSTRAINT uq_notification_delivery_attempt UNIQUE (notification_delivery_id, attempt_number, attempted_at),
    CONSTRAINT ck_notification_delivery_attempt_num CHECK (attempt_number >= 1)
) PARTITION BY RANGE (attempted_at);

CREATE TABLE engagement.notification_delivery_attempt_p202610 PARTITION OF engagement.notification_delivery_attempt
    FOR VALUES FROM ('2026-10-01 00:00:00+00') TO ('2026-11-01 00:00:00+00');
CREATE TABLE engagement.notification_delivery_attempt_p202611 PARTITION OF engagement.notification_delivery_attempt
    FOR VALUES FROM ('2026-11-01 00:00:00+00') TO ('2026-12-01 00:00:00+00');
CREATE TABLE engagement.notification_delivery_attempt_p_future PARTITION OF engagement.notification_delivery_attempt
    FOR VALUES FROM ('2026-12-01 00:00:00+00') TO ('2030-01-01 00:00:00+00');

CREATE TABLE engagement.provider_event_inbox (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    notification_provider_id bigint NOT NULL REFERENCES engagement.notification_provider(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    provider_event_id varchar(150) NOT NULL,
    payload_hash bytea NOT NULL,
    received_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    processed_at timestamptz NULL,
    CONSTRAINT uq_provider_event_inbox UNIQUE (notification_provider_id, provider_event_id)
);

CREATE INDEX idx_provider_event_inbox_pending ON engagement.provider_event_inbox (received_at) WHERE processed_at IS NULL;

CREATE TABLE engagement.contact_suppression (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user_account_id bigint NOT NULL REFERENCES administration.user_account(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    notification_channel_id bigint NOT NULL REFERENCES engagement.notification_channel(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    reason varchar(50) NOT NULL CHECK (reason IN ('bounced', 'complained', 'unsubscribed', 'manual_admin')),
    destination_hash bytea NOT NULL,
    suppressed_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    lifted_at timestamptz NULL,
    created_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by bigint NOT NULL REFERENCES administration.user_account(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    updated_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by bigint NOT NULL REFERENCES administration.user_account(id) ON UPDATE NO ACTION ON DELETE RESTRICT
);

CREATE UNIQUE INDEX uq_contact_suppression_active ON engagement.contact_suppression(user_account_id, notification_channel_id) WHERE (lifted_at IS NULL);

-- ============================================================================
-- 3. USER PREFERENCES & SEARCH CRITERIA (Entities 8 to 20)
-- ============================================================================

CREATE TABLE engagement.notification_preference (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user_account_id bigint NOT NULL REFERENCES administration.user_account(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    notification_type_id bigint NOT NULL REFERENCES engagement.notification_type(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    notification_channel_id bigint NOT NULL REFERENCES engagement.notification_channel(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    is_enabled boolean NOT NULL DEFAULT true,
    alert_frequency_id bigint NOT NULL REFERENCES engagement.alert_frequency(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    quiet_start_time time NULL,
    quiet_end_time time NULL,
    created_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by bigint NOT NULL REFERENCES administration.user_account(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    updated_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by bigint NOT NULL REFERENCES administration.user_account(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    CONSTRAINT uq_notification_preference_user_type_channel UNIQUE (user_account_id, notification_type_id, notification_channel_id),
    CONSTRAINT ck_notification_preference_quiet_hours CHECK (
        (quiet_start_time IS NULL AND quiet_end_time IS NULL) OR
        (quiet_start_time IS NOT NULL AND quiet_end_time IS NOT NULL)
    )
);

CREATE TABLE engagement.user_preference (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user_account_id bigint NOT NULL REFERENCES administration.user_account(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    language_id bigint NOT NULL REFERENCES master_data.language(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    timezone_name varchar(50) NOT NULL DEFAULT 'UTC',
    profile_visibility_level_id bigint NOT NULL REFERENCES engagement.visibility_level(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    contact_visibility_level_id bigint NOT NULL REFERENCES engagement.visibility_level(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    open_to_work_status_id bigint NOT NULL REFERENCES engagement.open_to_work_status(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    open_to_work_visibility_level_id bigint NOT NULL REFERENCES engagement.visibility_level(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    is_searchable_by_recruiters boolean NOT NULL DEFAULT true,
    created_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by bigint NOT NULL REFERENCES administration.user_account(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    updated_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by bigint NOT NULL REFERENCES administration.user_account(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    CONSTRAINT uq_user_preference_account UNIQUE (user_account_id)
);

CREATE TABLE engagement.search_criteria (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    search_target_code varchar(30) NOT NULL CHECK (search_target_code IN ('job', 'candidate', 'gig_request')),
    keyword_text varchar(200) NULL,
    experience_min_years numeric(4,1) NULL,
    experience_max_years numeric(4,1) NULL,
    salary_min numeric(14,2) NULL,
    salary_max numeric(14,2) NULL,
    currency_id bigint NULL REFERENCES master_data.currency(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    employment_type_id bigint NULL REFERENCES master_data.employment_type(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    created_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by bigint NOT NULL REFERENCES administration.user_account(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    updated_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by bigint NOT NULL REFERENCES administration.user_account(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    deleted_at timestamptz NULL,
    deleted_by bigint NULL REFERENCES administration.user_account(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    CONSTRAINT ck_search_criteria_experience CHECK (
        experience_min_years IS NULL OR experience_max_years IS NULL OR experience_min_years <= experience_max_years
    ),
    CONSTRAINT ck_search_criteria_salary CHECK (
        salary_min IS NULL OR salary_max IS NULL OR salary_min <= salary_max
    ),
    CONSTRAINT ck_search_criteria_currency CHECK (
        (salary_min IS NULL AND salary_max IS NULL) OR currency_id IS NOT NULL
    )
);

CREATE TABLE engagement.search_criteria_skill (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    search_criteria_id bigint NOT NULL REFERENCES engagement.search_criteria(id) ON UPDATE NO ACTION ON DELETE CASCADE,
    skill_id bigint NOT NULL REFERENCES master_data.skill(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    CONSTRAINT uq_search_criteria_skill UNIQUE (search_criteria_id, skill_id)
);

CREATE TABLE engagement.search_criteria_location (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    search_criteria_id bigint NOT NULL REFERENCES engagement.search_criteria(id) ON UPDATE NO ACTION ON DELETE CASCADE,
    city_id bigint NULL REFERENCES master_data.city(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    state_id bigint NULL REFERENCES master_data.state(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    country_id bigint NULL REFERENCES master_data.country(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    CONSTRAINT ck_search_criteria_location_nonnull CHECK (num_nonnulls(city_id, state_id, country_id) >= 1)
);

CREATE TABLE engagement.search_criteria_industry (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    search_criteria_id bigint NOT NULL REFERENCES engagement.search_criteria(id) ON UPDATE NO ACTION ON DELETE CASCADE,
    industry_id bigint NOT NULL REFERENCES master_data.industry(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    CONSTRAINT uq_search_criteria_industry UNIQUE (search_criteria_id, industry_id)
);

CREATE TABLE engagement.search_criteria_job_role (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    search_criteria_id bigint NOT NULL REFERENCES engagement.search_criteria(id) ON UPDATE NO ACTION ON DELETE CASCADE,
    job_role_id bigint NOT NULL REFERENCES master_data.job_role(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    CONSTRAINT uq_search_criteria_job_role UNIQUE (search_criteria_id, job_role_id)
);

CREATE TABLE IF NOT EXISTS master_data.job_category (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    code varchar(50) NOT NULL,
    category_name varchar(100) NOT NULL,
    is_active boolean NOT NULL DEFAULT true,
    sort_order integer NOT NULL DEFAULT 0,
    created_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by bigint NULL REFERENCES administration.user_account(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    updated_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by bigint NULL REFERENCES administration.user_account(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    CONSTRAINT uq_master_data_job_category_code UNIQUE (code),
    CONSTRAINT ck_master_data_job_category_code CHECK (code = lower(code) AND code ~ '^[a-z][a-z0-9_]*$')
);

CREATE TABLE engagement.search_criteria_job_category (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    search_criteria_id bigint NOT NULL REFERENCES engagement.search_criteria(id) ON UPDATE NO ACTION ON DELETE CASCADE,
    job_category_id bigint NOT NULL REFERENCES master_data.job_category(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    CONSTRAINT uq_search_criteria_job_category UNIQUE (search_criteria_id, job_category_id)
);

CREATE TABLE engagement.job_alert (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user_account_id bigint NOT NULL REFERENCES administration.user_account(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    search_criteria_id bigint NOT NULL REFERENCES engagement.search_criteria(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    alert_name varchar(100) NOT NULL,
    alert_frequency_id bigint NOT NULL REFERENCES engagement.alert_frequency(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    notification_channel_id bigint NOT NULL REFERENCES engagement.notification_channel(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    is_active boolean NOT NULL DEFAULT true,
    last_run_at timestamptz NULL,
    created_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by bigint NOT NULL REFERENCES administration.user_account(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    updated_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by bigint NOT NULL REFERENCES administration.user_account(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    deleted_at timestamptz NULL,
    deleted_by bigint NULL REFERENCES administration.user_account(id) ON UPDATE NO ACTION ON DELETE RESTRICT
);

CREATE UNIQUE INDEX uq_job_alert_user_name ON engagement.job_alert(user_account_id, alert_name) WHERE (deleted_at IS NULL);

CREATE TABLE engagement.job_alert_run (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    job_alert_id bigint NOT NULL REFERENCES engagement.job_alert(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    run_started_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    run_finished_at timestamptz NULL,
    match_count integer NOT NULL DEFAULT 0,
    CONSTRAINT ck_job_alert_run_count CHECK (match_count >= 0)
);

CREATE TABLE engagement.job_alert_delivery (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    job_alert_run_id bigint NOT NULL REFERENCES engagement.job_alert_run(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    job_requirement_id bigint NOT NULL REFERENCES recruitment.job_requirement(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    notification_delivery_id bigint NULL,
    notification_created_at timestamptz NULL,
    match_reason_text text NULL,
    created_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_job_alert_delivery_match UNIQUE (job_alert_run_id, job_requirement_id)
);

CREATE TABLE engagement.saved_search (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    owner_user_account_id bigint NOT NULL REFERENCES administration.user_account(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    organisation_id bigint NULL REFERENCES organisation.organisation(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    search_criteria_id bigint NOT NULL REFERENCES engagement.search_criteria(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    search_name varchar(100) NOT NULL,
    notify_on_new_match boolean NOT NULL DEFAULT false,
    created_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by bigint NOT NULL REFERENCES administration.user_account(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    updated_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by bigint NOT NULL REFERENCES administration.user_account(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    deleted_at timestamptz NULL,
    deleted_by bigint NULL REFERENCES administration.user_account(id) ON UPDATE NO ACTION ON DELETE RESTRICT
);

CREATE UNIQUE INDEX uq_saved_search_user_name ON engagement.saved_search(owner_user_account_id, search_name) WHERE (deleted_at IS NULL);

CREATE TABLE engagement.saved_search_match (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    saved_search_id bigint NOT NULL REFERENCES engagement.saved_search(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    candidate_profile_id bigint NOT NULL REFERENCES profile.candidate_profile(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    first_matched_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_saved_search_match UNIQUE (saved_search_id, candidate_profile_id)
);

-- ============================================================================
-- 4. FOLLOW GRAPH & COMMUNITY (Entities 21 to 28)
-- ============================================================================

CREATE TABLE engagement.community_topic (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    topic_label_key varchar(150) NOT NULL,
    slug varchar(80) NOT NULL,
    is_active boolean NOT NULL DEFAULT true,
    created_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by bigint NOT NULL REFERENCES administration.user_account(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    updated_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by bigint NOT NULL REFERENCES administration.user_account(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    CONSTRAINT uq_community_topic_slug UNIQUE (slug),
    CONSTRAINT ck_community_topic_slug CHECK (slug = lower(slug) AND slug ~ '^[a-z0-9-]+$')
);

CREATE TABLE engagement.follow_relation (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    follower_user_account_id bigint NOT NULL REFERENCES administration.user_account(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    followed_user_account_id bigint NULL REFERENCES administration.user_account(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    followed_organisation_id bigint NULL REFERENCES organisation.organisation(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    followed_community_topic_id bigint NULL REFERENCES engagement.community_topic(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    is_active boolean NOT NULL DEFAULT true,
    created_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by bigint NOT NULL REFERENCES administration.user_account(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    updated_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by bigint NOT NULL REFERENCES administration.user_account(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    CONSTRAINT ck_follow_relation_one_target CHECK (
        num_nonnulls(followed_user_account_id, followed_organisation_id, followed_community_topic_id) = 1
    ),
    CONSTRAINT ck_follow_relation_not_self CHECK (
        follower_user_account_id IS DISTINCT FROM followed_user_account_id
    )
);

CREATE UNIQUE INDEX uq_follow_relation_user ON engagement.follow_relation(follower_user_account_id, followed_user_account_id) WHERE followed_user_account_id IS NOT NULL;
CREATE UNIQUE INDEX uq_follow_relation_organisation ON engagement.follow_relation(follower_user_account_id, followed_organisation_id) WHERE followed_organisation_id IS NOT NULL;
CREATE UNIQUE INDEX uq_follow_relation_topic ON engagement.follow_relation(follower_user_account_id, followed_community_topic_id) WHERE followed_community_topic_id IS NOT NULL;

CREATE TABLE engagement.community_post (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    author_user_account_id bigint NOT NULL REFERENCES administration.user_account(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    content_text text NOT NULL,
    content_language_id bigint NOT NULL REFERENCES master_data.language(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    visibility_level_id bigint NOT NULL REFERENCES engagement.visibility_level(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    moderation_status_id bigint NOT NULL REFERENCES engagement.moderation_status(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    published_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    edited_at timestamptz NULL,
    created_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by bigint NOT NULL REFERENCES administration.user_account(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    updated_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by bigint NOT NULL REFERENCES administration.user_account(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    deleted_at timestamptz NULL,
    deleted_by bigint NULL REFERENCES administration.user_account(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    CONSTRAINT ck_community_post_len CHECK (char_length(content_text) <= 20000)
);

CREATE INDEX idx_community_post_published ON engagement.community_post(published_at DESC) WHERE (deleted_at IS NULL);
CREATE INDEX idx_community_post_author ON engagement.community_post(author_user_account_id);

CREATE TABLE engagement.community_post_topic (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    community_post_id bigint NOT NULL REFERENCES engagement.community_post(id) ON UPDATE NO ACTION ON DELETE CASCADE,
    community_topic_id bigint NOT NULL REFERENCES engagement.community_topic(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    CONSTRAINT uq_community_post_topic UNIQUE (community_post_id, community_topic_id)
);

CREATE TABLE engagement.community_reaction (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    community_post_id bigint NOT NULL REFERENCES engagement.community_post(id) ON UPDATE NO ACTION ON DELETE CASCADE,
    user_account_id bigint NOT NULL REFERENCES administration.user_account(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    reaction_type_id bigint NOT NULL REFERENCES engagement.reaction_type(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    created_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_community_reaction_post_user UNIQUE (community_post_id, user_account_id)
);

CREATE TABLE engagement.community_comment (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    community_post_id bigint NOT NULL REFERENCES engagement.community_post(id) ON UPDATE NO ACTION ON DELETE CASCADE,
    parent_community_comment_id bigint NULL REFERENCES engagement.community_comment(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    author_user_account_id bigint NOT NULL REFERENCES administration.user_account(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    content_text text NOT NULL,
    moderation_status_id bigint NOT NULL REFERENCES engagement.moderation_status(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    created_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by bigint NOT NULL REFERENCES administration.user_account(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    updated_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by bigint NOT NULL REFERENCES administration.user_account(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    deleted_at timestamptz NULL,
    deleted_by bigint NULL REFERENCES administration.user_account(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    CONSTRAINT ck_community_comment_len CHECK (char_length(content_text) <= 5000)
);

CREATE INDEX idx_community_comment_post ON engagement.community_comment(community_post_id, created_at) WHERE (deleted_at IS NULL);

CREATE TABLE engagement.community_report (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    community_post_id bigint NULL REFERENCES engagement.community_post(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    community_comment_id bigint NULL REFERENCES engagement.community_comment(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    reported_user_account_id bigint NULL REFERENCES administration.user_account(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    reporter_user_account_id bigint NOT NULL REFERENCES administration.user_account(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    report_reason_id bigint NOT NULL REFERENCES engagement.report_reason(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    review_status_id bigint NOT NULL REFERENCES engagement.review_status(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    reviewed_by_user_account_id bigint NULL REFERENCES administration.user_account(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    reviewed_at timestamptz NULL,
    created_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by bigint NOT NULL REFERENCES administration.user_account(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    updated_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by bigint NOT NULL REFERENCES administration.user_account(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    CONSTRAINT ck_community_report_one_target CHECK (
        num_nonnulls(community_post_id, community_comment_id, reported_user_account_id) = 1
    )
);

CREATE TABLE engagement.community_moderation_action (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    community_post_id bigint NULL REFERENCES engagement.community_post(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    community_comment_id bigint NULL REFERENCES engagement.community_comment(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    moderated_user_account_id bigint NULL REFERENCES administration.user_account(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    moderator_user_account_id bigint NOT NULL REFERENCES administration.user_account(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    moderation_action_type_id bigint NOT NULL REFERENCES engagement.moderation_action_type(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    community_report_id bigint NULL REFERENCES engagement.community_report(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    reason_text text NOT NULL,
    created_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by bigint NOT NULL REFERENCES administration.user_account(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    CONSTRAINT ck_community_mod_action_one_target CHECK (
        num_nonnulls(community_post_id, community_comment_id, moderated_user_account_id) = 1
    )
);

-- ============================================================================
-- 5. SUPPORT TICKETING & FAQS (Entities 29 to 34)
-- ============================================================================

CREATE TABLE engagement.support_ticket (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    requester_user_account_id bigint NOT NULL REFERENCES administration.user_account(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    organisation_id bigint NULL REFERENCES organisation.organisation(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    ticket_category_id bigint NOT NULL REFERENCES engagement.ticket_category(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    ticket_status_id bigint NOT NULL REFERENCES engagement.ticket_status(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    ticket_priority_id bigint NOT NULL REFERENCES engagement.ticket_priority(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    subject varchar(200) NOT NULL,
    assigned_to_user_account_id bigint NULL REFERENCES administration.user_account(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    first_response_due_at timestamptz NULL,
    resolution_due_at timestamptz NULL,
    closed_at timestamptz NULL,
    created_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by bigint NOT NULL REFERENCES administration.user_account(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    updated_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by bigint NOT NULL REFERENCES administration.user_account(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    CONSTRAINT ck_support_ticket_closed_order CHECK (closed_at IS NULL OR closed_at >= created_at)
);

CREATE INDEX idx_support_ticket_requester ON engagement.support_ticket(requester_user_account_id);
CREATE INDEX idx_support_ticket_status ON engagement.support_ticket(ticket_status_id);

CREATE TABLE engagement.support_ticket_message (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    support_ticket_id bigint NOT NULL REFERENCES engagement.support_ticket(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    author_user_account_id bigint NOT NULL REFERENCES administration.user_account(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    message_text text NOT NULL,
    is_internal_note boolean NOT NULL DEFAULT false,
    created_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by bigint NOT NULL REFERENCES administration.user_account(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    CONSTRAINT ck_support_ticket_message_len CHECK (char_length(message_text) <= 20000)
);

CREATE TABLE engagement.support_ticket_attachment (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    support_ticket_message_id bigint NOT NULL REFERENCES engagement.support_ticket_message(id) ON UPDATE NO ACTION ON DELETE CASCADE,
    storage_reference varchar(255) NOT NULL,
    content_type varchar(100) NOT NULL,
    size_bytes bigint NOT NULL,
    scan_status varchar(30) NOT NULL DEFAULT 'clean' CHECK (scan_status IN ('clean', 'pending', 'infected', 'rejected')),
    created_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by bigint NOT NULL REFERENCES administration.user_account(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    CONSTRAINT ck_support_ticket_attachment_size CHECK (size_bytes > 0 AND size_bytes <= 26214400) -- max 25MB
);

CREATE TABLE engagement.support_ticket_status_history (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    support_ticket_id bigint NOT NULL REFERENCES engagement.support_ticket(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    from_ticket_status_id bigint NOT NULL REFERENCES engagement.ticket_status(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    to_ticket_status_id bigint NOT NULL REFERENCES engagement.ticket_status(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    changed_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by bigint NOT NULL REFERENCES administration.user_account(id) ON UPDATE NO ACTION ON DELETE RESTRICT
);

CREATE TABLE engagement.faq (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    faq_category_id bigint NOT NULL REFERENCES engagement.faq_category(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    sort_order integer NOT NULL DEFAULT 0,
    is_published boolean NOT NULL DEFAULT true,
    created_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by bigint NOT NULL REFERENCES administration.user_account(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    updated_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by bigint NOT NULL REFERENCES administration.user_account(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    deleted_at timestamptz NULL,
    deleted_by bigint NULL REFERENCES administration.user_account(id) ON UPDATE NO ACTION ON DELETE RESTRICT
);

CREATE TABLE engagement.faq_translation (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    faq_id bigint NOT NULL REFERENCES engagement.faq(id) ON UPDATE NO ACTION ON DELETE CASCADE,
    language_id bigint NOT NULL REFERENCES master_data.language(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    question_text varchar(300) NOT NULL,
    answer_text text NOT NULL,
    created_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by bigint NOT NULL REFERENCES administration.user_account(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    updated_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by bigint NOT NULL REFERENCES administration.user_account(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    CONSTRAINT uq_faq_translation UNIQUE (faq_id, language_id)
);

-- ============================================================================
-- 6. GROWTH, REFERRALS & SOCIAL SHARING (Entities 35 to 38)
-- ============================================================================

CREATE TABLE engagement.referral_code (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    owner_user_account_id bigint NOT NULL REFERENCES administration.user_account(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    code varchar(50) NOT NULL,
    expires_at timestamptz NULL,
    usage_limit integer NOT NULL DEFAULT 100,
    usage_count integer NOT NULL DEFAULT 0,
    is_active boolean NOT NULL DEFAULT true,
    created_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by bigint NOT NULL REFERENCES administration.user_account(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    updated_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by bigint NOT NULL REFERENCES administration.user_account(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    CONSTRAINT uq_referral_code_code UNIQUE (code),
    CONSTRAINT ck_referral_code_shape CHECK (code = upper(code) AND code ~ '^[A-Z0-9_-]{4,50}$'),
    CONSTRAINT ck_referral_code_usage CHECK (usage_count >= 0 AND usage_count <= usage_limit)
);

CREATE TABLE engagement.referral_event (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    referral_code_id bigint NOT NULL REFERENCES engagement.referral_code(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    referrer_user_account_id bigint NOT NULL REFERENCES administration.user_account(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    referred_user_account_id bigint NULL REFERENCES administration.user_account(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    referral_event_type_id bigint NOT NULL REFERENCES engagement.referral_event_type(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    referral_source_channel_id bigint NOT NULL REFERENCES engagement.referral_source_channel(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    occurred_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT ck_referral_event_not_self CHECK (referrer_user_account_id IS DISTINCT FROM referred_user_account_id)
);

CREATE UNIQUE INDEX uq_referral_event_referred_signup 
    ON engagement.referral_event (referred_user_account_id) 
    WHERE (referred_user_account_id IS NOT NULL);

CREATE TABLE engagement.referral_reward (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    referral_event_id bigint NOT NULL REFERENCES engagement.referral_event(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    wallet_ledger_id bigint NULL REFERENCES billing.wallet_ledger(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    credit_amount integer NOT NULL CHECK (credit_amount > 0),
    currency_id bigint NULL REFERENCES master_data.currency(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    created_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by bigint NOT NULL REFERENCES administration.user_account(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    CONSTRAINT uq_referral_reward_event UNIQUE (referral_event_id)
);

CREATE TABLE engagement.share_event (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user_account_id bigint NOT NULL REFERENCES administration.user_account(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    shared_entity_name varchar(80) NOT NULL,
    shared_entity_id bigint NOT NULL,
    platform_code varchar(40) NOT NULL CHECK (platform_code IN ('linkedin', 'twitter_x', 'whatsapp', 'email', 'copy_link', 'other')),
    shared_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_share_event_user ON engagement.share_event(user_account_id, shared_at DESC);

-- ============================================================================
-- 7. AUTOMATED TRIGGERS & ENFORCEMENT FUNCTIONS
-- ============================================================================

-- A. Notification Delivery Gate (Consent, Preference, Suppression & Quiet Hours)
CREATE OR REPLACE FUNCTION engagement.fn_can_deliver(
    p_user_id bigint,
    p_type_id bigint,
    p_channel_id bigint
) RETURNS boolean LANGUAGE plpgsql STABLE AS $$
DECLARE
    v_is_mandatory boolean;
    v_pref_enabled boolean;
    v_has_suppression boolean;
BEGIN
    SELECT is_mandatory INTO v_is_mandatory
    FROM engagement.notification_type
    WHERE id = p_type_id;

    IF v_is_mandatory THEN
        RETURN true;
    END IF;

    -- Check active contact suppression
    SELECT EXISTS (
        SELECT 1 FROM engagement.contact_suppression
        WHERE user_account_id = p_user_id
          AND notification_channel_id = p_channel_id
          AND lifted_at IS NULL
    ) INTO v_has_suppression;

    IF v_has_suppression THEN
        RETURN false;
    END IF;

    -- Check notification preferences
    SELECT is_enabled INTO v_pref_enabled
    FROM engagement.notification_preference
    WHERE user_account_id = p_user_id
      AND notification_type_id = p_type_id
      AND notification_channel_id = p_channel_id;

    IF v_pref_enabled IS FALSE THEN
        RETURN false;
    END IF;

    RETURN true;
END $$;

-- B. Delivery Scheduled Guard Trigger
CREATE OR REPLACE FUNCTION engagement.fn_notification_delivery_guard()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
    IF NOT engagement.fn_can_deliver(NEW.recipient_user_account_id, (SELECT notification_type_id FROM engagement.notification WHERE id = NEW.notification_id), NEW.notification_channel_id) THEN
        RAISE EXCEPTION 'Notification delivery blocked by user preference or active contact suppression';
    END IF;
    RETURN NEW;
END $$;

CREATE TRIGGER trg_notification_delivery_guard
BEFORE INSERT ON engagement.notification_delivery
FOR EACH ROW EXECUTE FUNCTION engagement.fn_notification_delivery_guard();

-- C. Support Ticket Status History Logger
CREATE OR REPLACE FUNCTION engagement.fn_support_ticket_status_logger()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
    IF OLD.ticket_status_id <> NEW.ticket_status_id THEN
        INSERT INTO engagement.support_ticket_status_history (
            support_ticket_id, from_ticket_status_id, to_ticket_status_id, changed_at, created_by
        ) VALUES (
            NEW.id, OLD.ticket_status_id, NEW.ticket_status_id, CURRENT_TIMESTAMP, COALESCE(NEW.updated_by, NEW.created_by)
        );
    END IF;
    RETURN NEW;
END $$;

CREATE TRIGGER trg_support_ticket_status_history
AFTER UPDATE OF ticket_status_id ON engagement.support_ticket
FOR EACH ROW EXECUTE FUNCTION engagement.fn_support_ticket_status_logger();

-- D. Append-Only Enforcements
CREATE TRIGGER trg_notification_delivery_attempt_append_only
BEFORE UPDATE OR DELETE ON engagement.notification_delivery_attempt
FOR EACH ROW EXECUTE FUNCTION enforce_append_only();

CREATE TRIGGER trg_provider_event_inbox_append_only
BEFORE UPDATE OR DELETE ON engagement.provider_event_inbox
FOR EACH ROW EXECUTE FUNCTION enforce_append_only();

CREATE TRIGGER trg_saved_search_match_append_only
BEFORE UPDATE OR DELETE ON engagement.saved_search_match
FOR EACH ROW EXECUTE FUNCTION enforce_append_only();

CREATE TRIGGER trg_job_alert_run_append_only
BEFORE UPDATE OR DELETE ON engagement.job_alert_run
FOR EACH ROW EXECUTE FUNCTION enforce_append_only();

CREATE TRIGGER trg_job_alert_delivery_append_only
BEFORE UPDATE OR DELETE ON engagement.job_alert_delivery
FOR EACH ROW EXECUTE FUNCTION enforce_append_only();

CREATE TRIGGER trg_community_moderation_action_append_only
BEFORE UPDATE OR DELETE ON engagement.community_moderation_action
FOR EACH ROW EXECUTE FUNCTION enforce_append_only();

CREATE TRIGGER trg_support_ticket_message_append_only
BEFORE UPDATE OR DELETE ON engagement.support_ticket_message
FOR EACH ROW EXECUTE FUNCTION enforce_append_only();

CREATE TRIGGER trg_support_ticket_status_history_append_only
BEFORE UPDATE OR DELETE ON engagement.support_ticket_status_history
FOR EACH ROW EXECUTE FUNCTION enforce_append_only();

CREATE TRIGGER trg_referral_event_append_only
BEFORE UPDATE OR DELETE ON engagement.referral_event
FOR EACH ROW EXECUTE FUNCTION enforce_append_only();

CREATE TRIGGER trg_referral_reward_append_only
BEFORE UPDATE OR DELETE ON engagement.referral_reward
FOR EACH ROW EXECUTE FUNCTION enforce_append_only();

CREATE TRIGGER trg_share_event_append_only
BEFORE UPDATE OR DELETE ON engagement.share_event
FOR EACH ROW EXECUTE FUNCTION enforce_append_only();

-- E. Updated_at Maintenance Triggers
CREATE TRIGGER trg_notification_template_updated_at BEFORE UPDATE ON engagement.notification_template FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_notification_template_trans_updated_at BEFORE UPDATE ON engagement.notification_template_translation FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_contact_suppression_updated_at BEFORE UPDATE ON engagement.contact_suppression FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_notification_preference_updated_at BEFORE UPDATE ON engagement.notification_preference FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_user_preference_updated_at BEFORE UPDATE ON engagement.user_preference FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_search_criteria_updated_at BEFORE UPDATE ON engagement.search_criteria FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_job_alert_updated_at BEFORE UPDATE ON engagement.job_alert FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_saved_search_updated_at BEFORE UPDATE ON engagement.saved_search FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_community_topic_updated_at BEFORE UPDATE ON engagement.community_topic FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_follow_relation_updated_at BEFORE UPDATE ON engagement.follow_relation FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_community_post_updated_at BEFORE UPDATE ON engagement.community_post FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_community_reaction_updated_at BEFORE UPDATE ON engagement.community_reaction FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_community_comment_updated_at BEFORE UPDATE ON engagement.community_comment FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_community_report_updated_at BEFORE UPDATE ON engagement.community_report FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_support_ticket_updated_at BEFORE UPDATE ON engagement.support_ticket FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_faq_updated_at BEFORE UPDATE ON engagement.faq FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_faq_translation_updated_at BEFORE UPDATE ON engagement.faq_translation FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_referral_code_updated_at BEFORE UPDATE ON engagement.referral_code FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- ============================================================================
-- 8. ROW-LEVEL SECURITY & ACTIVE CONVENIENCE VIEWS
-- ============================================================================

ALTER TABLE engagement.notification_preference ENABLE ROW LEVEL SECURITY;
ALTER TABLE engagement.user_preference ENABLE ROW LEVEL SECURITY;
ALTER TABLE engagement.job_alert ENABLE ROW LEVEL SECURITY;
ALTER TABLE engagement.saved_search ENABLE ROW LEVEL SECURITY;
ALTER TABLE engagement.community_post ENABLE ROW LEVEL SECURITY;
ALTER TABLE engagement.community_comment ENABLE ROW LEVEL SECURITY;
ALTER TABLE engagement.support_ticket ENABLE ROW LEVEL SECURITY;

CREATE OR REPLACE VIEW engagement.v_active_community_feed AS
SELECT 
    p.id AS post_id,
    p.author_user_account_id,
    u.display_name AS author_display_name,
    p.content_text,
    p.content_language_id,
    p.published_at,
    p.edited_at,
    COUNT(DISTINCT r.id) AS reaction_count,
    COUNT(DISTINCT c.id) FILTER (WHERE c.deleted_at IS NULL) AS comment_count
FROM engagement.community_post p
JOIN administration.user_account u ON u.id = p.author_user_account_id
JOIN engagement.moderation_status m ON m.id = p.moderation_status_id
LEFT JOIN engagement.community_reaction r ON r.community_post_id = p.id
LEFT JOIN engagement.community_comment c ON c.community_post_id = p.id
WHERE p.deleted_at IS NULL AND m.code = 'approved'
GROUP BY p.id, p.author_user_account_id, u.display_name, p.content_text, p.content_language_id, p.published_at, p.edited_at;

CREATE OR REPLACE VIEW engagement.v_open_support_tickets AS
SELECT 
    t.id AS ticket_id,
    t.subject,
    c.code AS category_code,
    p.code AS priority_code,
    s.code AS status_code,
    t.requester_user_account_id,
    t.organisation_id,
    t.assigned_to_user_account_id,
    t.first_response_due_at,
    t.resolution_due_at,
    t.created_at
FROM engagement.support_ticket t
JOIN engagement.ticket_category c ON c.id = t.ticket_category_id
JOIN engagement.ticket_priority p ON p.id = t.ticket_priority_id
JOIN engagement.ticket_status s ON s.id = t.ticket_status_id
WHERE s.code NOT IN ('closed', 'resolved');

COMMIT;
