-- ============================================================================
-- Talentra: Job Search and Demand Management Platform
-- Database Schema Definition: Phase 2 Administration & Identity
-- Engine: PostgreSQL 14+
-- Conforming to: Talentra PRD Data Standards (Rule Groups 1 to 10)
-- Backlogs: B24 (Entities), B27 (Relationships), B30 (Columns), B33 (Keys, Constraints, RBAC, Audit)
-- Enterprise Enhancements: MFA / 2FA, Account Tokens, M2M Service API Keys, 
-- Consent Purpose Catalog, and Dynamic System Configuration.
-- ============================================================================

CREATE SCHEMA IF NOT EXISTS administration;

-- ============================================================================
-- 1. USER ACCOUNT (Core Principal Identity)
-- Canonical login identifier, verification states, and lifecycle status.
-- Conforms to Rule Group 1, 3 (lowercase email, E.164 phone), and 4 (lifecycle).
-- ============================================================================
CREATE TABLE administration.user_account (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    email varchar(254) NOT NULL,
    email_verified_at timestamptz NULL,
    phone_e164 varchar(16) NULL,
    phone_country_code varchar(10) NULL,
    phone_verified_at timestamptz NULL,
    display_name varchar(150) NULL,
    account_status_code varchar(30) NOT NULL DEFAULT 'active',
    failed_login_attempts integer NOT NULL DEFAULT 0,
    locked_until timestamptz NULL,
    last_authenticated_at timestamptz NULL,
    closed_at timestamptz NULL,
    created_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_by bigint NULL,
    updated_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_by bigint NULL,
    deleted_at timestamptz NULL,
    deleted_by bigint NULL,
    CONSTRAINT uq_user_account_email UNIQUE (email),
    CONSTRAINT chk_user_account_email_lower CHECK (email = lower(email)),
    CONSTRAINT chk_user_account_phone_e164 CHECK (phone_e164 IS NULL OR phone_e164 ~ '^\+[1-9][0-9]{1,14}$'),
    CONSTRAINT chk_user_account_status CHECK (account_status_code IN ('pending_verification', 'active', 'suspended', 'locked', 'closed')),
    CONSTRAINT chk_user_account_failed_logins CHECK (failed_login_attempts >= 0)
);

-- ============================================================================
-- 2. USER CREDENTIAL (Authentication Secrets)
-- Supports local passwords (Argon2id) and federated identities (OIDC/SAML).
-- Strictly forbids plaintext passwords per Rule Group 6.
-- ============================================================================
CREATE TABLE administration.user_credential (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user_account_id bigint NOT NULL,
    credential_type_code varchar(30) NOT NULL, -- 'password', 'oidc', 'saml', 'magic_link'
    password_hash text NULL, -- Argon2id hash only. Never plaintext.
    identity_provider_code varchar(80) NULL, -- 'google', 'linkedin', 'github', etc.
    provider_subject varchar(255) NULL, -- Subject ID from external identity provider
    is_active boolean NOT NULL DEFAULT true,
    created_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_by bigint NULL,
    updated_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_by bigint NULL,
    revoked_at timestamptz NULL,
    revoked_by bigint NULL,
    revoke_reason varchar(255) NULL,
    last_used_at timestamptz NULL,
    CONSTRAINT fk_user_credential_user_account_id FOREIGN KEY (user_account_id)
        REFERENCES administration.user_account(id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT chk_credential_type CHECK (credential_type_code IN ('password', 'oidc', 'saml', 'magic_link')),
    CONSTRAINT chk_credential_password_not_empty CHECK (
        credential_type_code <> 'password' OR (password_hash IS NOT NULL AND length(password_hash) >= 20)
    ),
    CONSTRAINT chk_credential_federated_shape CHECK (
        credential_type_code NOT IN ('oidc', 'saml') OR (identity_provider_code IS NOT NULL AND provider_subject IS NOT NULL)
    )
);

-- Active password uniqueness: at most one active password credential per user
CREATE UNIQUE INDEX uq_user_credential_active_password 
    ON administration.user_credential (user_account_id) 
    WHERE credential_type_code = 'password' AND is_active = true AND revoked_at IS NULL;

-- Federated subject uniqueness: provider + subject must be globally unique
CREATE UNIQUE INDEX uq_user_credential_provider_subject 
    ON administration.user_credential (identity_provider_code, provider_subject) 
    WHERE credential_type_code IN ('oidc', 'saml') AND revoked_at IS NULL;

-- ============================================================================
-- 3. ACCOUNT TOKEN (Ephemeral Verification & Reset Token Ledger)
-- Single-use cryptographically hashed tokens for password resets, email
-- verifications, phone OTPs, magic login links, and account invitations.
-- ============================================================================
CREATE TABLE administration.account_token (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user_account_id bigint NOT NULL,
    token_type_code varchar(40) NOT NULL, -- 'email_verification', 'password_reset', 'sms_otp', 'magic_link', 'account_invite'
    token_hash bytea NOT NULL, -- SHA-256 cryptographic hash of random secret
    recipient_destination varchar(254) NOT NULL, -- Target email address or E.164 phone number
    attempt_count integer NOT NULL DEFAULT 0,
    max_attempts integer NOT NULL DEFAULT 3,
    expires_at timestamptz NOT NULL,
    consumed_at timestamptz NULL,
    revoked_at timestamptz NULL,
    created_ip inet NULL,
    created_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT fk_account_token_user_account_id FOREIGN KEY (user_account_id)
        REFERENCES administration.user_account(id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT uq_account_token_hash UNIQUE (token_hash),
    CONSTRAINT chk_account_token_type CHECK (token_type_code IN ('email_verification', 'password_reset', 'sms_otp', 'magic_link', 'account_invite')),
    CONSTRAINT chk_account_token_attempts CHECK (attempt_count >= 0 AND attempt_count <= max_attempts),
    CONSTRAINT chk_account_token_expiry CHECK (expires_at > created_at),
    CONSTRAINT chk_account_token_consumed CHECK (consumed_at IS NULL OR consumed_at >= created_at)
);

CREATE INDEX idx_account_token_active_lookup 
    ON administration.account_token (user_account_id, token_type_code) 
    WHERE consumed_at IS NULL AND revoked_at IS NULL;

-- ============================================================================
-- 4. USER MFA FACTOR (Multi-Factor Authentication Authenticators)
-- Enrolled 2FA factors (TOTP Google Authenticator, WebAuthn / FIDO2 Passkeys, SMS).
-- Mandatory for administrative, hiring authority, and recruiter roles.
-- ============================================================================
CREATE TABLE administration.user_mfa_factor (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user_account_id bigint NOT NULL,
    factor_type_code varchar(30) NOT NULL, -- 'totp', 'webauthn_passkey', 'sms_otp', 'email_otp'
    factor_status_code varchar(30) NOT NULL DEFAULT 'unverified', -- 'unverified', 'active', 'revoked'
    friendly_name varchar(100) NOT NULL, -- e.g. 'Aarav iPhone Google Authenticator', 'YubiKey 5C NFC'
    secret_ciphertext text NULL, -- Encrypted TOTP secret key; NULL for WebAuthn
    credential_public_key text NULL, -- For WebAuthn/FIDO2 passkey public key credential
    credential_id_hash bytea NULL, -- WebAuthn credential ID hash
    is_primary boolean NOT NULL DEFAULT false,
    verified_at timestamptz NULL,
    last_used_at timestamptz NULL,
    revoked_at timestamptz NULL,
    created_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT fk_user_mfa_factor_user_account_id FOREIGN KEY (user_account_id)
        REFERENCES administration.user_account(id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT chk_user_mfa_factor_type CHECK (factor_type_code IN ('totp', 'webauthn_passkey', 'sms_otp', 'email_otp')),
    CONSTRAINT chk_user_mfa_factor_status CHECK (factor_status_code IN ('unverified', 'active', 'revoked')),
    CONSTRAINT chk_user_mfa_verified CHECK (factor_status_code <> 'active' OR verified_at IS NOT NULL)
);

CREATE INDEX idx_user_mfa_factor_active 
    ON administration.user_mfa_factor (user_account_id) 
    WHERE factor_status_code = 'active';

-- ============================================================================
-- 5. MFA BACKUP CODE (Disaster Recovery Emergency Codes)
-- Single-use hashed emergency recovery codes generated upon 2FA enrollment.
-- ============================================================================
CREATE TABLE administration.mfa_backup_code (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user_account_id bigint NOT NULL,
    code_hash bytea NOT NULL, -- Argon2id or SHA-256 hash of single-use recovery code
    is_consumed boolean NOT NULL DEFAULT false,
    consumed_at timestamptz NULL,
    consumed_ip inet NULL,
    created_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT fk_mfa_backup_code_user_account_id FOREIGN KEY (user_account_id)
        REFERENCES administration.user_account(id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT uq_mfa_backup_code_hash UNIQUE (user_account_id, code_hash),
    CONSTRAINT chk_mfa_backup_consumed CHECK (
        (is_consumed = false AND consumed_at IS NULL) OR 
        (is_consumed = true AND consumed_at IS NOT NULL)
    )
);

CREATE INDEX idx_mfa_backup_code_unconsumed 
    ON administration.mfa_backup_code (user_account_id) 
    WHERE is_consumed = false;

-- ============================================================================
-- 6. ROLE (Platform RBAC Roles)
-- Stable, named authorization personas per PRD (super_admin, admin, candidate, etc.)
-- ============================================================================
CREATE TABLE administration.role (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    code varchar(50) NOT NULL,
    display_name varchar(100) NOT NULL,
    description text NULL,
    is_system_role boolean NOT NULL DEFAULT true,
    is_active boolean NOT NULL DEFAULT true,
    created_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_by bigint NULL,
    updated_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_by bigint NULL,
    CONSTRAINT uq_role_code UNIQUE (code),
    CONSTRAINT chk_role_code_lower CHECK (code = lower(code))
);

-- ============================================================================
-- 7. PERMISSION (Atomic Capabilities)
-- Resource:action capabilities (e.g. 'candidate_profile:read_own', 'user:suspend')
-- ============================================================================
CREATE TABLE administration.permission (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    code varchar(80) NOT NULL,
    resource_code varchar(50) NOT NULL,
    action_code varchar(50) NOT NULL,
    description text NULL,
    created_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_by bigint NULL,
    CONSTRAINT uq_permission_code UNIQUE (code),
    CONSTRAINT chk_permission_code_lower CHECK (code = lower(code))
);

-- ============================================================================
-- 8. USER ROLE (Temporal User-Role Assignments)
-- Maps users to platform roles with temporal validity (valid_from/valid_until)
-- and explicit revocation metadata.
-- ============================================================================
CREATE TABLE administration.user_role (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user_account_id bigint NOT NULL,
    role_id bigint NOT NULL,
    valid_from timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    valid_until timestamptz NULL,
    revoked_at timestamptz NULL,
    revoked_by bigint NULL,
    revoke_reason varchar(255) NULL,
    created_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_by bigint NULL,
    CONSTRAINT fk_user_role_user_account_id FOREIGN KEY (user_account_id)
        REFERENCES administration.user_account(id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_user_role_role_id FOREIGN KEY (role_id)
        REFERENCES administration.role(id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT chk_user_role_validity_window CHECK (valid_until IS NULL OR valid_until > valid_from)
);

-- Unique active assignment per user-role pair (prevents duplicate simultaneous active grants)
CREATE UNIQUE INDEX uq_user_role_active_assignment 
    ON administration.user_role (user_account_id, role_id) 
    WHERE revoked_at IS NULL;

-- ============================================================================
-- 9. ROLE PERMISSION (Mapping Permissions to Roles)
-- Many-to-many matrix defining which permissions each role possesses.
-- ============================================================================
CREATE TABLE administration.role_permission (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    role_id bigint NOT NULL,
    permission_id bigint NOT NULL,
    created_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_by bigint NULL,
    CONSTRAINT fk_role_permission_role_id FOREIGN KEY (role_id)
        REFERENCES administration.role(id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_role_permission_permission_id FOREIGN KEY (permission_id)
        REFERENCES administration.permission(id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT uq_role_permission_pair UNIQUE (role_id, permission_id)
);

-- ============================================================================
-- 10. IDENTITY SESSION (Bearer Session State)
-- Tracks active and revoked user authentication sessions.
-- Cryptographically hashes the session token (SHA-256 bytea).
-- ============================================================================
CREATE TABLE administration.identity_session (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user_account_id bigint NOT NULL,
    session_token_hash bytea NOT NULL, -- SHA-256 hash of random opaque bearer token
    session_status_code varchar(20) NOT NULL DEFAULT 'active', -- 'active', 'revoked', 'expired'
    started_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    last_activity_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    expires_at timestamptz NOT NULL,
    ended_at timestamptz NULL,
    revoke_reason_code varchar(40) NULL, -- 'logout', 'admin_revoke', 'password_reset', 'security_event'
    source_ip inet NULL,
    user_agent varchar(512) NULL,
    device_identifier_hash bytea NULL,
    CONSTRAINT fk_identity_session_user_account_id FOREIGN KEY (user_account_id)
        REFERENCES administration.user_account(id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT chk_session_status CHECK (session_status_code IN ('active', 'revoked', 'expired')),
    CONSTRAINT chk_session_expiry_order CHECK (expires_at > started_at),
    CONSTRAINT chk_session_end_order CHECK (ended_at IS NULL OR ended_at >= started_at),
    CONSTRAINT chk_session_revoked_consistency CHECK (
        (session_status_code = 'revoked' AND ended_at IS NOT NULL AND revoke_reason_code IS NOT NULL) OR
        (session_status_code <> 'revoked')
    )
);

-- Fast active session lookup index by user
CREATE INDEX idx_identity_session_active_lookup 
    ON administration.identity_session (user_account_id, expires_at) 
    WHERE session_status_code = 'active';

-- High-throughput token hash lookup on every authenticated request (O(1) B-tree seek)
CREATE UNIQUE INDEX uq_identity_session_token_hash 
    ON administration.identity_session (session_token_hash);

-- ============================================================================
-- 11. SERVICE API KEY (Machine-to-Machine / Headless Integrations)
-- Headless API keys for ATS integrations (Workday, Greenhouse), HRIS,
-- webhook consumers, and scheduled background daemons.
-- ============================================================================
CREATE TABLE administration.service_api_key (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user_account_id bigint NOT NULL,
    name varchar(150) NOT NULL, -- e.g. 'Workday ATS Sync Daemon'
    key_prefix varchar(16) NOT NULL, -- e.g. 'tla_live_' (shown for identification)
    key_hash bytea NOT NULL, -- SHA-256 cryptographic hash of secret key
    allowed_cidr_block cidr NULL, -- Optional IP restriction
    rate_limit_per_minute integer NOT NULL DEFAULT 600,
    scopes varchar(50)[] NOT NULL DEFAULT ARRAY['read']::varchar[],
    expires_at timestamptz NULL,
    last_used_at timestamptz NULL,
    revoked_at timestamptz NULL,
    revoke_reason varchar(150) NULL,
    created_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_by bigint NULL,
    updated_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_by bigint NULL,
    CONSTRAINT fk_service_api_key_user_account_id FOREIGN KEY (user_account_id)
        REFERENCES administration.user_account(id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT uq_service_api_key_hash UNIQUE (key_hash),
    CONSTRAINT chk_service_api_key_prefix CHECK (key_prefix ~ '^[a-zA-Z0-9_\-]+$'),
    CONSTRAINT chk_service_api_key_rate_limit CHECK (rate_limit_per_minute > 0)
);

CREATE INDEX idx_service_api_key_prefix 
    ON administration.service_api_key (key_prefix) 
    WHERE revoked_at IS NULL;

-- ============================================================================
-- 12. CONSENT PURPOSE (Master Catalog for DPDP / GDPR Privacy Notices)
-- Regulated purpose catalog defining lawful processing bases, notice versions,
-- retention periods, and mandatory vs optional flags.
-- ============================================================================
CREATE TABLE administration.consent_purpose (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    code varchar(80) NOT NULL,
    title varchar(150) NOT NULL,
    description text NULL,
    lawful_basis_code varchar(40) NOT NULL DEFAULT 'consent',
    is_mandatory boolean NOT NULL DEFAULT false,
    retention_days integer NULL,
    active_notice_version varchar(40) NOT NULL DEFAULT 'v1.0',
    is_active boolean NOT NULL DEFAULT true,
    created_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_by bigint NULL,
    updated_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_by bigint NULL,
    CONSTRAINT uq_consent_purpose_code UNIQUE (code),
    CONSTRAINT chk_consent_purpose_code_lower CHECK (code = lower(code)),
    CONSTRAINT chk_consent_purpose_lawful_basis CHECK (lawful_basis_code IN (
        'consent', 'contractual_necessity', 'legal_obligation', 
        'vital_interest', 'public_task', 'legitimate_interest'
    )),
    CONSTRAINT chk_consent_purpose_retention CHECK (retention_days IS NULL OR retention_days > 0)
);

-- ============================================================================
-- 13. CONSENT RECORD (Append-Only Privacy Evidence)
-- Conforms to DPDP Act 2023 / GDPR consent tracking.
-- Append-only: Grant, withdrawal, and modifications are strictly new rows.
-- ============================================================================
CREATE TABLE administration.consent_record (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user_account_id bigint NOT NULL,
    consent_purpose_id bigint NULL,
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
    CONSTRAINT fk_consent_record_consent_purpose_id FOREIGN KEY (consent_purpose_id)
        REFERENCES administration.consent_purpose(id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT chk_consent_decision CHECK (decision_code IN ('granted', 'withdrawn', 'declined', 'acknowledged'))
);

-- ============================================================================
-- 14. SYSTEM SETTING (Dynamic Enterprise Operational Configuration)
-- Key-value runtime policies (lockout thresholds, maintenance mode, upload limits)
-- ============================================================================
CREATE TABLE administration.system_setting (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    setting_key varchar(100) NOT NULL,
    setting_value text NOT NULL,
    value_data_type varchar(30) NOT NULL DEFAULT 'string', -- 'string', 'integer', 'boolean', 'json', 'duration'
    category_code varchar(50) NOT NULL DEFAULT 'security', -- 'security', 'compliance', 'platform', 'billing', 'notifications'
    is_public boolean NOT NULL DEFAULT false, -- Safe for frontend bootstrap consumption
    is_encrypted boolean NOT NULL DEFAULT false,
    description text NULL,
    created_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_by bigint NULL,
    updated_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_by bigint NULL,
    CONSTRAINT uq_system_setting_key UNIQUE (setting_key),
    CONSTRAINT chk_system_setting_key_lower CHECK (setting_key = lower(setting_key)),
    CONSTRAINT chk_system_setting_type CHECK (value_data_type IN ('string', 'integer', 'boolean', 'json', 'duration')),
    CONSTRAINT chk_system_setting_category CHECK (category_code IN ('security', 'compliance', 'platform', 'billing', 'notifications'))
);

-- ============================================================================
-- 15. AUDIT EVENT (Forensic Security Log)
-- Append-only ledger recording all security-critical operations.
-- Strictly prohibits storage of passwords, clear tokens, or raw secrets.
-- ============================================================================
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

-- ============================================================================
-- 16. USER BLOCK (Directional User-to-User Blocking)
-- Allows a candidate to unilaterally block recruiters, employers, or consultants.
-- Self-blocking is strictly prohibited.
-- ============================================================================
CREATE TABLE administration.user_block (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    blocker_user_id bigint NOT NULL,
    blocked_user_id bigint NOT NULL,
    reason_code varchar(40) NOT NULL DEFAULT 'user_requested',
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

-- Active block uniqueness: at most one active block edge between blocker and blocked user
CREATE UNIQUE INDEX uq_user_block_active_pair 
    ON administration.user_block (blocker_user_id, blocked_user_id) 
    WHERE lifted_at IS NULL;

-- ============================================================================
-- 17. ORGANISATION BLOCK (Candidate-to-Organisation Blocking Contract)
-- Reserved integration contract. Organisation FK target wired when Member B
-- confirms canonical organisation table and key.
-- ============================================================================
CREATE TABLE administration.organisation_block (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    blocker_user_id bigint NOT NULL,
    organisation_id bigint NOT NULL, -- Wire FK when Member B confirms organisation table
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

CREATE TRIGGER trg_user_credential_updated_at BEFORE UPDATE ON administration.user_credential
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_user_mfa_factor_updated_at BEFORE UPDATE ON administration.user_mfa_factor
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_role_updated_at BEFORE UPDATE ON administration.role
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_service_api_key_updated_at BEFORE UPDATE ON administration.service_api_key
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_consent_purpose_updated_at BEFORE UPDATE ON administration.consent_purpose
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_system_setting_updated_at BEFORE UPDATE ON administration.system_setting
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- Append-only enforcement on audit logs and consent evidence
CREATE TRIGGER trg_audit_event_append_only BEFORE UPDATE OR DELETE ON administration.audit_event
FOR EACH ROW EXECUTE FUNCTION enforce_append_only();

CREATE TRIGGER trg_consent_record_append_only BEFORE UPDATE OR DELETE ON administration.consent_record
FOR EACH ROW EXECUTE FUNCTION enforce_append_only();

-- ----------------------------------------------------------------------------
-- LAST SUPER_ADMIN DELETION/DEMOTION PROTECTION (ADM-024)
-- Enforces that the platform can never become orphaned without an active super_admin
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION administration.protect_last_super_admin()
RETURNS TRIGGER AS $$
DECLARE
    v_super_admin_role_id bigint;
    v_active_super_admins integer;
BEGIN
    SELECT id INTO v_super_admin_role_id 
    FROM administration.role WHERE code = 'super_admin';

    IF (TG_TABLE_NAME = 'user_role') THEN
        IF (OLD.role_id = v_super_admin_role_id AND (NEW.revoked_at IS NOT NULL OR TG_OP = 'DELETE')) THEN
            SELECT count(*) INTO v_active_super_admins
            FROM administration.user_role ur
            JOIN administration.user_account ua ON ua.id = ur.user_account_id
            WHERE ur.role_id = v_super_admin_role_id
              AND ur.revoked_at IS NULL
              AND ua.account_status_code = 'active'
              AND ua.deleted_at IS NULL
              AND ur.id <> OLD.id;

            IF (v_active_super_admins = 0) THEN
                RAISE EXCEPTION 'Cannot revoke or delete the last active super_admin role assignment'
                    USING ERRCODE = '23514';
            END IF;
        END IF;
    ELSIF (TG_TABLE_NAME = 'user_account') THEN
        IF (OLD.account_status_code = 'active' AND (NEW.account_status_code <> 'active' OR NEW.deleted_at IS NOT NULL)) THEN
            IF EXISTS (
                SELECT 1 FROM administration.user_role 
                WHERE user_account_id = OLD.id 
                  AND role_id = v_super_admin_role_id 
                  AND revoked_at IS NULL
            ) THEN
                SELECT count(*) INTO v_active_super_admins
                FROM administration.user_role ur
                JOIN administration.user_account ua ON ua.id = ur.user_account_id
                WHERE ur.role_id = v_super_admin_role_id
                  AND ur.revoked_at IS NULL
                  AND ua.account_status_code = 'active'
                  AND ua.deleted_at IS NULL
                  AND ua.id <> OLD.id;

                IF (v_active_super_admins = 0) THEN
                    RAISE EXCEPTION 'Cannot suspend, lock, close, or delete the last active super_admin account'
                        USING ERRCODE = '23514';
                END IF;
            END IF;
        END IF;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_protect_last_super_admin_role
BEFORE UPDATE OF revoked_at OR DELETE ON administration.user_role
FOR EACH ROW EXECUTE FUNCTION administration.protect_last_super_admin();

CREATE TRIGGER trg_protect_last_super_admin_account
BEFORE UPDATE OF account_status_code, deleted_at OR DELETE ON administration.user_account
FOR EACH ROW EXECUTE FUNCTION administration.protect_last_super_admin();


-- ============================================================================
-- HIGH-PERFORMANCE ACCESS PATHS & INDEXES (B33)
-- ============================================================================

-- Audit trail access paths
CREATE INDEX idx_admin_audit_event_actor_time ON administration.audit_event USING btree (actor_user_id, occurred_at DESC);
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
COMMENT ON COLUMN administration.account_token.recipient_destination IS 'Classification: Personal';
COMMENT ON COLUMN administration.identity_session.source_ip IS 'Classification: Personal';
COMMENT ON COLUMN administration.audit_event.source_ip IS 'Classification: Personal';
COMMENT ON COLUMN administration.user_block.blocker_user_id IS 'Classification: Personal';
COMMENT ON COLUMN administration.user_block.blocked_user_id IS 'Classification: Personal';

-- Sensitive Authentication Secrets (Sensitive)
COMMENT ON COLUMN administration.user_credential.password_hash IS 'Classification: Sensitive';
COMMENT ON COLUMN administration.user_credential.provider_subject IS 'Classification: Sensitive';
COMMENT ON COLUMN administration.account_token.token_hash IS 'Classification: Sensitive';
COMMENT ON COLUMN administration.user_mfa_factor.secret_ciphertext IS 'Classification: Sensitive';
COMMENT ON COLUMN administration.mfa_backup_code.code_hash IS 'Classification: Sensitive';
COMMENT ON COLUMN administration.service_api_key.key_hash IS 'Classification: Sensitive';
COMMENT ON COLUMN administration.identity_session.session_token_hash IS 'Classification: Sensitive';
COMMENT ON COLUMN administration.consent_record.evidence_reference IS 'Classification: Sensitive';

-- Internal System Metadata (Internal)
COMMENT ON COLUMN administration.user_account.account_status_code IS 'Classification: Internal';
COMMENT ON COLUMN administration.role.code IS 'Classification: Internal';
COMMENT ON COLUMN administration.permission.code IS 'Classification: Internal';
COMMENT ON COLUMN administration.consent_purpose.code IS 'Classification: Internal';
COMMENT ON COLUMN administration.system_setting.setting_key IS 'Classification: Internal';
COMMENT ON COLUMN administration.audit_event.action_code IS 'Classification: Internal';
COMMENT ON COLUMN administration.audit_event.metadata IS 'Classification: Internal';
