-- ============================================================================
-- Talentra: Job Search and Demand Management Platform
-- Database Schema Definition (Phase 2: Administration & Identity Module)
-- Engine: PostgreSQL 14+
-- Conforming to: Talentra PRD Data Standards (Rule Groups 1 to 10)
-- Implementing: Milestones 7–10 (Backlogs B24, B27, B30, B33)
-- ============================================================================

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SET check_function_bodies = false;
SET client_min_messages = warning;
SET row_security = off;

-- ----------------------------------------------------------------------------
-- SCHEMA DEFINITION
-- ----------------------------------------------------------------------------
CREATE SCHEMA IF NOT EXISTS administration;

-- ============================================================================
-- MODULE: ADMINISTRATION & IDENTITY
-- Users, credentials, roles, permissions, sessions, consent, audit, and blocking.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. USER ACCOUNT (Core Identity Principal)
-- Rule 1: snake_case, singular noun, id bigint identity PK.
-- Rule 3: Canonical lowercase email up to 254 chars, E.164 phone.
-- Rule 4: Standard audit lifecycle timestamps + soft delete.
-- Closed Decision: Email remains permanently unique for v1 across all accounts.
-- ----------------------------------------------------------------------------
CREATE TABLE administration.user_account (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    email varchar(254) NOT NULL,
    email_verified_at timestamptz NULL,
    phone_e164 varchar(16) NULL,
    phone_country_code varchar(10) NULL,
    phone_verified_at timestamptz NULL,
    display_name varchar(150) NULL,
    account_status_code varchar(30) NOT NULL DEFAULT 'active',
    last_authenticated_at timestamptz NULL,
    closed_at timestamptz NULL,
    created_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_by bigint NULL,
    updated_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_by bigint NULL,
    deleted_at timestamptz NULL,
    CONSTRAINT uq_user_account_email UNIQUE (email),
    CONSTRAINT chk_user_account_email_lower CHECK (email = lower(email)),
    CONSTRAINT chk_user_account_phone_e164 CHECK (phone_e164 IS NULL OR phone_e164 ~ '^\+[1-9][0-9]{1,14}$'),
    CONSTRAINT chk_user_account_status CHECK (account_status_code IN ('pending_verification', 'active', 'suspended', 'locked', 'closed'))
);

-- ----------------------------------------------------------------------------
-- 2. USER CREDENTIAL (Authentication Secrets & Federated Identities)
-- Stored separately from account; supports Argon2id password hash or OAuth/OIDC.
-- Passwords never stored in plaintext or reversible encryption.
-- ----------------------------------------------------------------------------
CREATE TABLE administration.user_credential (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user_account_id bigint NOT NULL,
    credential_type_code varchar(30) NOT NULL, -- 'password', 'oidc', 'saml', 'magic_link'
    password_hash text NULL, -- Argon2id hash only; NULL for federated credentials
    identity_provider_code varchar(80) NULL, -- 'google', 'linkedin', 'github', etc.
    provider_subject varchar(255) NULL, -- Unique identifier from external IDP
    is_active boolean NOT NULL DEFAULT true,
    created_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_by bigint NULL,
    rotated_at timestamptz NULL,
    revoked_at timestamptz NULL,
    CONSTRAINT fk_user_credential_user_account_id FOREIGN KEY (user_account_id)
        REFERENCES administration.user_account(id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT chk_user_credential_type CHECK (credential_type_code IN ('password', 'oidc', 'saml', 'magic_link')),
    CONSTRAINT chk_user_credential_shape CHECK (
        (credential_type_code = 'password' AND password_hash IS NOT NULL) OR
        (credential_type_code IN ('oidc', 'saml') AND identity_provider_code IS NOT NULL AND provider_subject IS NOT NULL) OR
        (credential_type_code = 'magic_link')
    )
);

-- Active federated credential uniqueness per provider
CREATE UNIQUE INDEX uq_user_credential_provider 
    ON administration.user_credential (identity_provider_code, provider_subject) 
    WHERE provider_subject IS NOT NULL AND revoked_at IS NULL;

-- At most one active password credential per user account
CREATE UNIQUE INDEX uq_user_credential_active_password 
    ON administration.user_credential (user_account_id) 
    WHERE credential_type_code = 'password' AND is_active = true AND revoked_at IS NULL;

-- ----------------------------------------------------------------------------
-- 3. ROLE (Platform Authorization Roles)
-- Stable system roles: super_admin, admin, account_admin, guest, candidate,
-- employer, recruiter, consultant, placement_officer.
-- ----------------------------------------------------------------------------
CREATE TABLE administration.role (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    code varchar(50) NOT NULL,
    display_name varchar(100) NOT NULL,
    description varchar(500) NULL,
    is_system_role boolean NOT NULL DEFAULT false,
    is_active boolean NOT NULL DEFAULT true,
    created_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_by bigint NULL,
    updated_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_by bigint NULL,
    CONSTRAINT uq_role_code UNIQUE (code)
);

-- ----------------------------------------------------------------------------
-- 4. PERMISSION (Atomic Capabilities: Resource Namespace + Action Verb)
-- Example: 'candidate_profile.read', 'job_requirement.publish', 'audit.read'
-- ----------------------------------------------------------------------------
CREATE TABLE administration.permission (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    code varchar(100) NOT NULL,
    resource_code varchar(60) NOT NULL,
    action_code varchar(40) NOT NULL,
    description varchar(500) NULL,
    is_active boolean NOT NULL DEFAULT true,
    created_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_by bigint NULL,
    CONSTRAINT uq_permission_code UNIQUE (code),
    CONSTRAINT uq_permission_resource_action UNIQUE (resource_code, action_code)
);

-- ----------------------------------------------------------------------------
-- 5. USER ROLE (Temporal Assignment of Roles to User Accounts)
-- Supports effective dates (valid_from, valid_until) and explicit revocation.
-- ----------------------------------------------------------------------------
CREATE TABLE administration.user_role (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user_account_id bigint NOT NULL,
    role_id bigint NOT NULL,
    valid_from timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    valid_until timestamptz NULL,
    assigned_by bigint NULL,
    revoked_at timestamptz NULL,
    revoked_by bigint NULL,
    revocation_reason varchar(255) NULL,
    CONSTRAINT fk_user_role_user_account_id FOREIGN KEY (user_account_id)
        REFERENCES administration.user_account(id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_user_role_role_id FOREIGN KEY (role_id)
        REFERENCES administration.role(id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT chk_user_role_dates CHECK (valid_until IS NULL OR valid_until > valid_from),
    CONSTRAINT chk_user_role_revocation CHECK (
        (revoked_at IS NULL AND revoked_by IS NULL) OR 
        (revoked_at IS NOT NULL AND revoked_at >= valid_from)
    )
);

-- Unique active assignment per user-role pair (prevents duplicate simultaneous active grants)
CREATE UNIQUE INDEX uq_user_role_active_assignment 
    ON administration.user_role (user_account_id, role_id) 
    WHERE revoked_at IS NULL AND (valid_until IS NULL OR valid_until > CURRENT_TIMESTAMP);

-- ----------------------------------------------------------------------------
-- 6. ROLE PERMISSION (Mapping Permissions to Roles)
-- Many-to-many bridge table with surrogate PK per Rule Group 2.
-- ----------------------------------------------------------------------------
CREATE TABLE administration.role_permission (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    role_id bigint NOT NULL,
    permission_id bigint NOT NULL,
    granted_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    granted_by bigint NULL,
    CONSTRAINT fk_role_permission_role_id FOREIGN KEY (role_id)
        REFERENCES administration.role(id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_role_permission_permission_id FOREIGN KEY (permission_id)
        REFERENCES administration.permission(id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT uq_role_permission UNIQUE (role_id, permission_id)
);

-- ----------------------------------------------------------------------------
-- 7. IDENTITY SESSION (Authenticated Sessions & Token Hashes)
-- Tokens are hashed (bytea SHA-256); raw tokens are never persisted.
-- ----------------------------------------------------------------------------
CREATE TABLE administration.identity_session (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user_account_id bigint NOT NULL,
    session_token_hash bytea NOT NULL,
    session_status_code varchar(20) NOT NULL DEFAULT 'active', -- 'active', 'revoked', 'expired'
    started_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    last_activity_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    expires_at timestamptz NOT NULL,
    ended_at timestamptz NULL,
    revoke_reason_code varchar(40) NULL, -- 'logout', 'admin_revoke', 'password_reset', 'account_suspended', 'security_event'
    source_ip inet NULL,
    user_agent varchar(512) NULL,
    created_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT fk_identity_session_user_account_id FOREIGN KEY (user_account_id)
        REFERENCES administration.user_account(id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT chk_session_status CHECK (session_status_code IN ('active', 'revoked', 'expired')),
    CONSTRAINT chk_session_dates CHECK (expires_at > started_at AND (ended_at IS NULL OR ended_at >= started_at)),
    CONSTRAINT chk_session_state CHECK (
        (session_status_code = 'active' AND ended_at IS NULL) OR
        (session_status_code IN ('revoked', 'expired') AND ended_at IS NOT NULL)
    )
);

-- Fast active session lookup index
CREATE INDEX idx_identity_session_active_lookup 
    ON administration.identity_session (user_account_id, expires_at) 
    WHERE session_status_code = 'active';

-- ----------------------------------------------------------------------------
-- 8. CONSENT RECORD (Append-Only Privacy Evidence)
-- Conforms to DPDP Act 2023 / GDPR consent tracking.
-- Append-only: Grant, withdrawal, and modifications are strictly new rows.
-- ----------------------------------------------------------------------------
CREATE TABLE administration.consent_record (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user_account_id bigint NOT NULL,
    purpose_code varchar(80) NOT NULL, -- 'recruitment_matching', 'direct_outreach', 'profile_discovery', etc.
    notice_version varchar(40) NOT NULL,
    decision_code varchar(20) NOT NULL, -- 'granted', 'withdrawn', 'declined', 'acknowledged'
    recorded_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    collection_source_code varchar(30) NOT NULL, -- 'web', 'mobile', 'admin', 'import'
    evidence_reference varchar(255) NULL,
    policy_effective_at timestamptz NULL,
    request_id varchar(100) NULL,
    CONSTRAINT fk_consent_record_user_account_id FOREIGN KEY (user_account_id)
        REFERENCES administration.user_account(id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT chk_consent_decision CHECK (decision_code IN ('granted', 'withdrawn', 'declined', 'acknowledged'))
);

-- ----------------------------------------------------------------------------
-- 9. AUDIT EVENT (Forensic Security Log)
-- Append-only ledger recording all security-critical operations.
-- Strictly prohibits storage of passwords, clear tokens, or raw secrets.
-- ----------------------------------------------------------------------------
CREATE TABLE administration.audit_event (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    occurred_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    actor_user_id bigint NULL,
    actor_type_code varchar(30) NOT NULL, -- 'user', 'system', 'service', 'anonymous'
    action_code varchar(100) NOT NULL,
    resource_type varchar(80) NOT NULL,
    resource_id varchar(150) NULL,
    outcome_code varchar(20) NOT NULL, -- 'success', 'denied', 'failure'
    reason_code varchar(80) NULL,
    request_id varchar(100) NULL,
    source_ip inet NULL,
    user_agent varchar(512) NULL,
    metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
    CONSTRAINT fk_audit_event_actor_user_id FOREIGN KEY (actor_user_id)
        REFERENCES administration.user_account(id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT chk_audit_outcome CHECK (outcome_code IN ('success', 'denied', 'failure')),
    CONSTRAINT chk_audit_actor_shape CHECK (
        (actor_type_code = 'user' AND actor_user_id IS NOT NULL) OR
        (actor_type_code IN ('system', 'service', 'anonymous'))
    )
);

-- ----------------------------------------------------------------------------
-- 10. USER BLOCK (Directional Principal-to-Principal Blocking)
-- Candidates may block employers, recruiters, or consultants.
-- Self-blocking is rejected at the engine level.
-- ----------------------------------------------------------------------------
CREATE TABLE administration.user_block (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    blocker_user_id bigint NOT NULL,
    blocked_user_id bigint NOT NULL,
    reason_code varchar(40) NOT NULL DEFAULT 'user_requested', -- 'user_requested', 'safety', 'policy'
    created_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_by bigint NULL,
    lifted_at timestamptz NULL,
    lifted_by bigint NULL,
    lift_reason varchar(255) NULL,
    CONSTRAINT fk_user_block_blocker FOREIGN KEY (blocker_user_id)
        REFERENCES administration.user_account(id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_user_block_blocked FOREIGN KEY (blocked_user_id)
        REFERENCES administration.user_account(id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT chk_user_block_not_self CHECK (blocker_user_id <> blocked_user_id)
);

-- Unique active block per blocker/blocked pair (lifting retains history)
CREATE UNIQUE INDEX uq_user_block_active_pair 
    ON administration.user_block (blocker_user_id, blocked_user_id) 
    WHERE lifted_at IS NULL;

-- ----------------------------------------------------------------------------
-- 11. ORGANISATION BLOCK (Directional User-to-Organisation Blocking)
-- Reserved integration contract for Member B's organisation module.
-- ----------------------------------------------------------------------------
CREATE TABLE administration.organisation_block (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    blocker_user_id bigint NOT NULL,
    organisation_id bigint NOT NULL, -- Target FK to be wired once Member B confirms table name
    reason_code varchar(40) NOT NULL DEFAULT 'user_requested',
    created_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_by bigint NULL,
    lifted_at timestamptz NULL,
    lifted_by bigint NULL,
    lift_reason varchar(255) NULL,
    CONSTRAINT fk_organisation_block_blocker FOREIGN KEY (blocker_user_id)
        REFERENCES administration.user_account(id) ON UPDATE RESTRICT ON DELETE RESTRICT
);

CREATE UNIQUE INDEX uq_organisation_block_active_pair 
    ON administration.organisation_block (blocker_user_id, organisation_id) 
    WHERE lifted_at IS NULL;


-- ============================================================================
-- AUTOMATED TRIGGERS (Rule Group 4 & 10)
-- ============================================================================

-- updated_at maintenance triggers on mutable tables
CREATE TRIGGER trg_user_account_updated_at BEFORE UPDATE ON administration.user_account
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_role_updated_at BEFORE UPDATE ON administration.role
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- Append-only enforcement on audit logs and consent evidence
CREATE TRIGGER trg_audit_event_append_only BEFORE UPDATE OR DELETE ON administration.audit_event
FOR EACH ROW EXECUTE FUNCTION enforce_append_only();

CREATE TRIGGER trg_consent_record_append_only BEFORE UPDATE OR DELETE ON administration.consent_record
FOR EACH ROW EXECUTE FUNCTION enforce_append_only();


-- ============================================================================
-- HIGH-PERFORMANCE ACCESS PATHS & INDEXES (B33)
-- ============================================================================

-- Audit trail access paths
CREATE INDEX idx_audit_event_actor_time ON administration.audit_event USING btree (actor_user_id, occurred_at DESC);
CREATE INDEX idx_audit_event_resource_time ON administration.audit_event USING btree (resource_type, resource_id, occurred_at DESC);
CREATE INDEX idx_audit_event_action_time ON administration.audit_event USING btree (action_code, occurred_at DESC);

-- Authorization resolution access paths
CREATE INDEX idx_user_role_user_id ON administration.user_role USING btree (user_account_id);
CREATE INDEX idx_user_role_role_id ON administration.user_role USING btree (role_id);
CREATE INDEX idx_role_permission_role_id ON administration.role_permission USING btree (role_id);
CREATE INDEX idx_role_permission_permission_id ON administration.role_permission USING btree (permission_id);

-- Candidate visibility blocking query paths
CREATE INDEX idx_user_block_blocked_active ON administration.user_block USING btree (blocked_user_id, blocker_user_id) WHERE lifted_at IS NULL;
CREATE INDEX idx_organisation_block_org_active ON administration.organisation_block USING btree (organisation_id, blocker_user_id) WHERE lifted_at IS NULL;

-- Consent latest decision query path
CREATE INDEX idx_consent_record_user_purpose ON administration.consent_record USING btree (user_account_id, purpose_code, recorded_at DESC);


-- ============================================================================
-- SENSITIVE DATA CLASSIFICATIONS (Rule Group 6)
-- Public, Internal, Personal, Sensitive
-- ============================================================================

-- Personal Identifiers (Personal)
COMMENT ON COLUMN administration.user_account.email IS 'Classification: Personal';
COMMENT ON COLUMN administration.user_account.phone_e164 IS 'Classification: Personal';
COMMENT ON COLUMN administration.user_account.display_name IS 'Classification: Personal';
COMMENT ON COLUMN administration.identity_session.source_ip IS 'Classification: Personal';
COMMENT ON COLUMN administration.audit_event.source_ip IS 'Classification: Personal';
COMMENT ON COLUMN administration.user_block.blocker_user_id IS 'Classification: Personal';
COMMENT ON COLUMN administration.user_block.blocked_user_id IS 'Classification: Personal';

-- Sensitive Authentication Secrets (Sensitive)
COMMENT ON COLUMN administration.user_credential.password_hash IS 'Classification: Sensitive';
COMMENT ON COLUMN administration.user_credential.provider_subject IS 'Classification: Sensitive';
COMMENT ON COLUMN administration.identity_session.session_token_hash IS 'Classification: Sensitive';
COMMENT ON COLUMN administration.consent_record.evidence_reference IS 'Classification: Sensitive';

-- Internal System Metadata (Internal)
COMMENT ON COLUMN administration.user_account.account_status_code IS 'Classification: Internal';
COMMENT ON COLUMN administration.role.code IS 'Classification: Internal';
COMMENT ON COLUMN administration.permission.code IS 'Classification: Internal';
COMMENT ON COLUMN administration.audit_event.action_code IS 'Classification: Internal';
COMMENT ON COLUMN administration.audit_event.metadata IS 'Classification: Internal';
