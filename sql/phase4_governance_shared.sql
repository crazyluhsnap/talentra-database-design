-- ============================================================================
-- Talentra Enterprise Database Architecture
-- Phase 4 - Module C: Shared Team Items & Advanced Governance (administration)
-- PostgreSQL 16+
--
-- Conforming to:
-- - Talentra Phase 4: Entities and Relationships Specification (Module C)
-- - Talentra Phase 4: Gap Analysis and Revised Schema (Gaps C01 - C13, 7.1 - 7.6)
--
-- Architectural Principle:
-- Reconciles upstream entities with zero duplication (Gap C01).
-- Reuses existing user_credential, identity_session, registered_device, user_block,
-- and organisation_block from Phase 2/3 and attaches missing shared items:
-- 1. 16 Lookups (Rule Group 3 Standard Pattern)
-- 2. 8 Governance & Integration Entities:
--    - consent_policy (Versioned DPDP/GDPR policy terms with temporal GiST exclusion)
--    - credential_reset_token (Append-only, single-use, SHA-256 token hash)
--    - system_error_log (Append-only operational telemetry, 90 days retention)
--    - identity_verification (Third-party KYC/ID verification state & encrypted token)
--    - integration_exchange (External boundary webhook & idempotency log)
--    - retention_policy (Entity-level automated purge/anonymisation rules)
--    - data_subject_request (DPDP/GDPR Subject Access & Right-to-Erasure Requests)
--    - login_attempt (Monthly partitioned authentication security audit stream)
-- 3. Core Enforcement Mechanisms:
--    - candidate_visible_to() function enforcing directional individual & corporate blocks
--    - Row-Level Security candidate_profile_select policy integration
--    - start_user_session() function enforcing concurrent session and device limits
-- ============================================================================

\set ON_ERROR_STOP on

BEGIN;

CREATE EXTENSION IF NOT EXISTS btree_gist;

-- ============================================================================
-- 1. LOOKUP TABLES (16 Lookups for Governance, Privacy & Integrations)
-- ============================================================================

CREATE TABLE administration.credential_type (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    code varchar(50) NOT NULL,
    label_key varchar(150) NOT NULL,
    is_active boolean NOT NULL DEFAULT true,
    sort_order integer NOT NULL DEFAULT 0,
    created_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by bigint NOT NULL REFERENCES administration.user_account(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    updated_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by bigint NOT NULL REFERENCES administration.user_account(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    CONSTRAINT uq_credential_type_code UNIQUE (code),
    CONSTRAINT ck_credential_type_code CHECK (code = lower(code) AND code ~ '^[a-z][a-z0-9_]*$')
);

CREATE TABLE administration.consent_type (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    code varchar(50) NOT NULL,
    label_key varchar(150) NOT NULL,
    is_active boolean NOT NULL DEFAULT true,
    sort_order integer NOT NULL DEFAULT 0,
    created_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by bigint NOT NULL REFERENCES administration.user_account(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    updated_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by bigint NOT NULL REFERENCES administration.user_account(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    CONSTRAINT uq_consent_type_code UNIQUE (code),
    CONSTRAINT ck_consent_type_code CHECK (code = lower(code) AND code ~ '^[a-z][a-z0-9_]*$')
);

CREATE TABLE administration.consent_status (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    code varchar(50) NOT NULL,
    label_key varchar(150) NOT NULL,
    is_active boolean NOT NULL DEFAULT true,
    sort_order integer NOT NULL DEFAULT 0,
    created_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by bigint NOT NULL REFERENCES administration.user_account(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    updated_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by bigint NOT NULL REFERENCES administration.user_account(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    CONSTRAINT uq_consent_status_code UNIQUE (code),
    CONSTRAINT ck_consent_status_code CHECK (code = lower(code) AND code ~ '^[a-z][a-z0-9_]*$')
);

CREATE TABLE administration.session_end_reason (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    code varchar(50) NOT NULL,
    label_key varchar(150) NOT NULL,
    is_active boolean NOT NULL DEFAULT true,
    sort_order integer NOT NULL DEFAULT 0,
    created_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by bigint NOT NULL REFERENCES administration.user_account(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    updated_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by bigint NOT NULL REFERENCES administration.user_account(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    CONSTRAINT uq_session_end_reason_code UNIQUE (code),
    CONSTRAINT ck_session_end_reason_code CHECK (code = lower(code) AND code ~ '^[a-z][a-z0-9_]*$')
);

CREATE TABLE administration.login_outcome (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    code varchar(50) NOT NULL,
    label_key varchar(150) NOT NULL,
    is_active boolean NOT NULL DEFAULT true,
    sort_order integer NOT NULL DEFAULT 0,
    created_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by bigint NOT NULL REFERENCES administration.user_account(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    updated_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by bigint NOT NULL REFERENCES administration.user_account(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    CONSTRAINT uq_login_outcome_code UNIQUE (code),
    CONSTRAINT ck_login_outcome_code CHECK (code = lower(code) AND code ~ '^[a-z][a-z0-9_]*$')
);

CREATE TABLE administration.login_failure_reason (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    code varchar(50) NOT NULL,
    label_key varchar(150) NOT NULL,
    is_active boolean NOT NULL DEFAULT true,
    sort_order integer NOT NULL DEFAULT 0,
    created_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by bigint NOT NULL REFERENCES administration.user_account(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    updated_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by bigint NOT NULL REFERENCES administration.user_account(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    CONSTRAINT uq_login_failure_reason_code UNIQUE (code),
    CONSTRAINT ck_login_failure_reason_code CHECK (code = lower(code) AND code ~ '^[a-z][a-z0-9_]*$')
);

CREATE TABLE administration.audit_action (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    code varchar(50) NOT NULL,
    label_key varchar(150) NOT NULL,
    is_active boolean NOT NULL DEFAULT true,
    sort_order integer NOT NULL DEFAULT 0,
    created_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by bigint NOT NULL REFERENCES administration.user_account(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    updated_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by bigint NOT NULL REFERENCES administration.user_account(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    CONSTRAINT uq_admin_audit_action_code UNIQUE (code),
    CONSTRAINT ck_admin_audit_action_code CHECK (code = lower(code) AND code ~ '^[a-z][a-z0-9_]*$')
);

CREATE TABLE administration.audit_outcome (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    code varchar(50) NOT NULL,
    label_key varchar(150) NOT NULL,
    is_active boolean NOT NULL DEFAULT true,
    sort_order integer NOT NULL DEFAULT 0,
    created_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by bigint NOT NULL REFERENCES administration.user_account(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    updated_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by bigint NOT NULL REFERENCES administration.user_account(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    CONSTRAINT uq_audit_outcome_code UNIQUE (code),
    CONSTRAINT ck_audit_outcome_code CHECK (code = lower(code) AND code ~ '^[a-z][a-z0-9_]*$')
);

CREATE TABLE administration.block_reason (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    code varchar(50) NOT NULL,
    label_key varchar(150) NOT NULL,
    is_active boolean NOT NULL DEFAULT true,
    sort_order integer NOT NULL DEFAULT 0,
    created_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by bigint NOT NULL REFERENCES administration.user_account(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    updated_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by bigint NOT NULL REFERENCES administration.user_account(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    CONSTRAINT uq_block_reason_code UNIQUE (code),
    CONSTRAINT ck_block_reason_code CHECK (code = lower(code) AND code ~ '^[a-z][a-z0-9_]*$')
);

CREATE TABLE administration.identity_verification_outcome (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    code varchar(50) NOT NULL,
    label_key varchar(150) NOT NULL,
    is_active boolean NOT NULL DEFAULT true,
    sort_order integer NOT NULL DEFAULT 0,
    created_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by bigint NOT NULL REFERENCES administration.user_account(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    updated_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by bigint NOT NULL REFERENCES administration.user_account(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    CONSTRAINT uq_identity_verification_outcome_code UNIQUE (code),
    CONSTRAINT ck_identity_verification_outcome_code CHECK (code = lower(code) AND code ~ '^[a-z][a-z0-9_]*$')
);

CREATE TABLE administration.integration_boundary (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    code varchar(50) NOT NULL,
    label_key varchar(150) NOT NULL,
    is_active boolean NOT NULL DEFAULT true,
    sort_order integer NOT NULL DEFAULT 0,
    created_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by bigint NOT NULL REFERENCES administration.user_account(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    updated_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by bigint NOT NULL REFERENCES administration.user_account(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    CONSTRAINT uq_integration_boundary_code UNIQUE (code),
    CONSTRAINT ck_integration_boundary_code CHECK (code = lower(code) AND code ~ '^[a-z][a-z0-9_]*$')
);

CREATE TABLE administration.exchange_status (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    code varchar(50) NOT NULL,
    label_key varchar(150) NOT NULL,
    is_active boolean NOT NULL DEFAULT true,
    sort_order integer NOT NULL DEFAULT 0,
    created_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by bigint NOT NULL REFERENCES administration.user_account(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    updated_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by bigint NOT NULL REFERENCES administration.user_account(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    CONSTRAINT uq_exchange_status_code UNIQUE (code),
    CONSTRAINT ck_exchange_status_code CHECK (code = lower(code) AND code ~ '^[a-z][a-z0-9_]*$')
);

CREATE TABLE administration.data_request_type (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    code varchar(50) NOT NULL,
    label_key varchar(150) NOT NULL,
    is_active boolean NOT NULL DEFAULT true,
    sort_order integer NOT NULL DEFAULT 0,
    created_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by bigint NOT NULL REFERENCES administration.user_account(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    updated_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by bigint NOT NULL REFERENCES administration.user_account(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    CONSTRAINT uq_data_request_type_code UNIQUE (code),
    CONSTRAINT ck_data_request_type_code CHECK (code = lower(code) AND code ~ '^[a-z][a-z0-9_]*$')
);

CREATE TABLE administration.data_request_status (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    code varchar(50) NOT NULL,
    label_key varchar(150) NOT NULL,
    is_active boolean NOT NULL DEFAULT true,
    sort_order integer NOT NULL DEFAULT 0,
    created_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by bigint NOT NULL REFERENCES administration.user_account(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    updated_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by bigint NOT NULL REFERENCES administration.user_account(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    CONSTRAINT uq_data_request_status_code UNIQUE (code),
    CONSTRAINT ck_data_request_status_code CHECK (code = lower(code) AND code ~ '^[a-z][a-z0-9_]*$')
);

CREATE TABLE administration.error_severity (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    code varchar(50) NOT NULL,
    label_key varchar(150) NOT NULL,
    is_active boolean NOT NULL DEFAULT true,
    sort_order integer NOT NULL DEFAULT 0,
    created_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by bigint NOT NULL REFERENCES administration.user_account(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    updated_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by bigint NOT NULL REFERENCES administration.user_account(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    CONSTRAINT uq_error_severity_code UNIQUE (code),
    CONSTRAINT ck_error_severity_code CHECK (code = lower(code) AND code ~ '^[a-z][a-z0-9_]*$')
);

CREATE TABLE administration.retention_action (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    code varchar(50) NOT NULL,
    label_key varchar(150) NOT NULL,
    is_active boolean NOT NULL DEFAULT true,
    sort_order integer NOT NULL DEFAULT 0,
    created_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by bigint NOT NULL REFERENCES administration.user_account(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    updated_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by bigint NOT NULL REFERENCES administration.user_account(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    CONSTRAINT uq_retention_action_code UNIQUE (code),
    CONSTRAINT ck_retention_action_code CHECK (code = lower(code) AND code ~ '^[a-z][a-z0-9_]*$')
);

-- ============================================================================
-- 2. PRIVACY POLICIES, TOKENS & OPERATIONAL LOGS (Entities 1 to 8)
-- ============================================================================

CREATE TABLE administration.consent_policy (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    consent_type_id bigint NOT NULL REFERENCES administration.consent_type(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    version_label varchar(50) NOT NULL,
    effective_from date NOT NULL,
    effective_to date NULL, -- NULL = active current version
    document_reference varchar(255) NOT NULL,
    created_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by bigint NOT NULL REFERENCES administration.user_account(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    updated_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by bigint NOT NULL REFERENCES administration.user_account(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    CONSTRAINT uq_consent_policy_version UNIQUE (consent_type_id, version_label),
    CONSTRAINT ck_consent_policy_period CHECK (effective_to IS NULL OR effective_to > effective_from),
    CONSTRAINT ex_consent_policy_period EXCLUDE USING gist (
        consent_type_id WITH =,
        daterange(effective_from, effective_to, '[)') WITH &&
    )
);

CREATE TABLE administration.credential_reset_token (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user_credential_id bigint NOT NULL REFERENCES administration.user_credential(id) ON UPDATE NO ACTION ON DELETE CASCADE,
    token_hash bytea NOT NULL,
    purpose varchar(50) NOT NULL DEFAULT 'password_reset',
    expires_at timestamptz NOT NULL,
    used_at timestamptz NULL,
    created_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by bigint NOT NULL REFERENCES administration.user_account(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    CONSTRAINT uq_credential_reset_token_hash UNIQUE (token_hash),
    CONSTRAINT ck_credential_reset_token_expiry CHECK (expires_at > created_at)
);

CREATE TABLE administration.system_error_log (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    occurred_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    error_severity_id bigint NOT NULL REFERENCES administration.error_severity(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    component varchar(100) NOT NULL,
    error_code varchar(80) NOT NULL,
    message_text varchar(2000) NOT NULL, -- Personal data scrubbed
    request_id varchar(100) NULL,
    user_account_id bigint NULL REFERENCES administration.user_account(id) ON UPDATE NO ACTION ON DELETE RESTRICT
);

CREATE INDEX idx_system_error_log_severity_time ON administration.system_error_log(error_severity_id, occurred_at DESC);

CREATE TABLE administration.identity_verification (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user_account_id bigint NOT NULL REFERENCES administration.user_account(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    provider_code varchar(80) NOT NULL,
    verification_outcome_id bigint NOT NULL REFERENCES administration.identity_verification_outcome(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    token_encrypted text NOT NULL, -- Encrypted verification payload / KMS token
    verified_at timestamptz NULL,
    expires_at timestamptz NULL,
    created_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by bigint NOT NULL REFERENCES administration.user_account(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    updated_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by bigint NOT NULL REFERENCES administration.user_account(id) ON UPDATE NO ACTION ON DELETE RESTRICT
);

CREATE TABLE administration.integration_exchange (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    integration_boundary_id bigint NOT NULL REFERENCES administration.integration_boundary(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    direction varchar(10) NOT NULL CHECK (direction IN ('inbound', 'outbound')),
    idempotency_key varchar(150) NOT NULL,
    external_reference varchar(255) NULL,
    exchange_status_id bigint NOT NULL REFERENCES administration.exchange_status(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    request_hash bytea NOT NULL,
    occurred_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    related_entity_name varchar(80) NULL,
    related_entity_id bigint NULL,
    CONSTRAINT uq_integration_exchange_key UNIQUE (integration_boundary_id, idempotency_key)
);

CREATE TABLE administration.retention_policy (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    entity_name varchar(100) NOT NULL,
    retention_interval interval NOT NULL,
    retention_action_id bigint NOT NULL REFERENCES administration.retention_action(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    legal_basis_text text NOT NULL,
    is_active boolean NOT NULL DEFAULT true,
    created_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by bigint NOT NULL REFERENCES administration.user_account(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    updated_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by bigint NOT NULL REFERENCES administration.user_account(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    CONSTRAINT uq_retention_policy_entity UNIQUE (entity_name)
);

CREATE TABLE administration.data_subject_request (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user_account_id bigint NOT NULL REFERENCES administration.user_account(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    data_request_type_id bigint NOT NULL REFERENCES administration.data_request_type(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    data_request_status_id bigint NOT NULL REFERENCES administration.data_request_status(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    received_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    due_at timestamptz NOT NULL,
    completed_at timestamptz NULL,
    handled_by_user_account_id bigint NULL REFERENCES administration.user_account(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    created_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by bigint NOT NULL REFERENCES administration.user_account(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    updated_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by bigint NOT NULL REFERENCES administration.user_account(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    CONSTRAINT ck_data_subject_request_due CHECK (due_at >= received_at)
);

CREATE TABLE administration.login_attempt (
    id bigint GENERATED ALWAYS AS IDENTITY,
    occurred_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    user_account_id bigint NULL REFERENCES administration.user_account(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    identifier_hash bytea NOT NULL,
    login_outcome_id bigint NOT NULL REFERENCES administration.login_outcome(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    login_failure_reason_id bigint NULL REFERENCES administration.login_failure_reason(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    source_ip_hash bytea NOT NULL,
    user_device_id bigint NULL,
    PRIMARY KEY (id, occurred_at)
) PARTITION BY RANGE (occurred_at);

CREATE TABLE administration.login_attempt_p202610 PARTITION OF administration.login_attempt
    FOR VALUES FROM ('2026-10-01 00:00:00+00') TO ('2026-11-01 00:00:00+00');
CREATE TABLE administration.login_attempt_p202611 PARTITION OF administration.login_attempt
    FOR VALUES FROM ('2026-11-01 00:00:00+00') TO ('2026-12-01 00:00:00+00');
CREATE TABLE administration.login_attempt_p_future PARTITION OF administration.login_attempt
    FOR VALUES FROM ('2026-12-01 00:00:00+00') TO ('2030-01-01 00:00:00+00');

CREATE INDEX idx_login_attempt_user ON administration.login_attempt(user_account_id, occurred_at DESC);

-- ============================================================================
-- 3. CORE ENFORCEMENT FUNCTIONS (Sections 7.1 & 7.2)
-- ============================================================================

-- A. Candidate Blocking Enforcement Function
-- Checks if viewer is blocked as an individual OR via an employer organization
CREATE OR REPLACE FUNCTION administration.candidate_visible_to(
    p_viewer bigint,
    p_candidate_profile_id bigint
) RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER AS $$
SELECT NOT EXISTS (
    -- Individual block
    SELECT 1 FROM profile.candidate_profile cp
    JOIN administration.user_block ub ON ub.blocker_user_id = cp.user_account_id
    WHERE cp.id = p_candidate_profile_id
      AND ub.blocked_user_id = p_viewer
      AND ub.lifted_at IS NULL
)
AND NOT EXISTS (
    -- Organizational block
    SELECT 1 FROM profile.candidate_profile cp
    JOIN administration.organisation_block ob ON ob.blocker_user_id = cp.user_account_id
    JOIN organisation.organisation_recruiter orc ON orc.organisation_id = ob.blocked_organisation_id
    WHERE cp.id = p_candidate_profile_id
      AND orc.recruiter_user_account_id = p_viewer
      AND orc.deleted_at IS NULL
      AND ob.lifted_at IS NULL
);
$$;

-- B. Concurrent Device & Session Limit Enforcer (Section 7.2 C02)
CREATE OR REPLACE FUNCTION administration.start_user_session(
    p_user bigint,
    p_licence bigint,
    p_device bigint,
    p_token_hash bytea,
    p_ttl interval
) RETURNS bigint LANGUAGE plpgsql AS $$
DECLARE
    v_max integer := 3;
    v_active integer;
    v_id bigint;
    v_audit_action_id bigint;
    v_audit_outcome_id bigint;
BEGIN
    PERFORM 1 FROM administration.user_account WHERE id = p_user FOR UPDATE;

    SELECT COALESCE(max_devices_per_user, 3) INTO v_max 
    FROM licence.licence 
    WHERE id = p_licence;

    SELECT count(*) INTO v_active
    FROM administration.identity_session
    WHERE user_account_id = p_user
      AND revoked_at IS NULL
      AND expires_at > CURRENT_TIMESTAMP;

    IF v_active >= v_max THEN
        -- Audit session limit denied without rolling back
        SELECT id INTO v_audit_action_id FROM administration.audit_action WHERE code = 'session_limit_exceeded';
        SELECT id INTO v_audit_outcome_id FROM administration.audit_outcome WHERE code = 'denied';

        INSERT INTO administration.audit_event (
            actor_user_id, actor_type_code, action_code, resource_type,
            resource_id, outcome_code, reason_code, occurred_at
        )
        VALUES (
            p_user, 'user', 'session_limit_exceeded', 'identity_session',
            p_user::text, 'denied', 'concurrent_device_cap_reached', CURRENT_TIMESTAMP
        );

        RETURN NULL;
    END IF;

    INSERT INTO administration.identity_session (
        user_account_id, session_token_hash, expires_at, created_at
    )
    VALUES (
        p_user, p_token_hash, CURRENT_TIMESTAMP + p_ttl, CURRENT_TIMESTAMP
    )
    RETURNING id INTO v_id;

    RETURN v_id;
END $$;

-- C. Append-Only Enforcements
CREATE TRIGGER trg_credential_reset_token_append_only
BEFORE UPDATE OR DELETE ON administration.credential_reset_token
FOR EACH ROW EXECUTE FUNCTION enforce_append_only();

CREATE TRIGGER trg_system_error_log_append_only
BEFORE UPDATE OR DELETE ON administration.system_error_log
FOR EACH ROW EXECUTE FUNCTION enforce_append_only();

CREATE TRIGGER trg_integration_exchange_append_only
BEFORE UPDATE OR DELETE ON administration.integration_exchange
FOR EACH ROW EXECUTE FUNCTION enforce_append_only();

CREATE TRIGGER trg_login_attempt_append_only
BEFORE UPDATE OR DELETE ON administration.login_attempt
FOR EACH ROW EXECUTE FUNCTION enforce_append_only();

-- D. Updated_at Maintenance Triggers
CREATE TRIGGER trg_consent_policy_updated_at BEFORE UPDATE ON administration.consent_policy FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_identity_verification_updated_at BEFORE UPDATE ON administration.identity_verification FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_retention_policy_updated_at BEFORE UPDATE ON administration.retention_policy FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_data_subject_request_updated_at BEFORE UPDATE ON administration.data_subject_request FOR EACH ROW EXECUTE FUNCTION set_updated_at();

COMMIT;
