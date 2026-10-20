-- ============================================================================
-- Talentra: Job Search and Demand Management Platform
-- Database Schema Definition: Phase 2 Organisation and Account Module
-- Engine: PostgreSQL 14+
-- Conforming to: Talentra PRD Data Standards (Rule Groups 1 to 10)
-- Backlogs: B25 (Entities), B28 (Relationships), B31 (Columns), B34 (Keys & Constraints)
-- Verified against: 24 Module Entities Specification (Revised v2)
-- ============================================================================

CREATE EXTENSION IF NOT EXISTS btree_gist;
CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE SCHEMA IF NOT EXISTS organisation;

-- ============================================================================
-- 1. LOOKUP TABLES (Rule Group 3, 5, 7)
-- Lookups share standard columns: code, ui_label_id, is_active, sort_order.
-- ============================================================================

CREATE TABLE organisation.organisation_status (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    code varchar(50) NOT NULL,
    ui_label_id bigint NULL,
    is_active boolean DEFAULT true NOT NULL,
    sort_order integer DEFAULT 0 NOT NULL,
    created_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_by bigint NULL,
    updated_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_by bigint NULL,
    CONSTRAINT uq_organisation_status_code UNIQUE (code),
    CONSTRAINT chk_organisation_status_code CHECK (code ~ '^[a-z][a-z0-9_]*$'),
    CONSTRAINT chk_organisation_status_sort_order CHECK (sort_order >= 0)
);

CREATE TABLE organisation.organisation_type (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    code varchar(50) NOT NULL,
    ui_label_id bigint NULL,
    is_active boolean DEFAULT true NOT NULL,
    sort_order integer DEFAULT 0 NOT NULL,
    created_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_by bigint NULL,
    updated_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_by bigint NULL,
    CONSTRAINT uq_organisation_type_code UNIQUE (code),
    CONSTRAINT chk_organisation_type_code CHECK (code ~ '^[a-z][a-z0-9_]*$'),
    CONSTRAINT chk_organisation_type_sort_order CHECK (sort_order >= 0)
);

CREATE TABLE organisation.company_size_band (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    code varchar(50) NOT NULL,
    ui_label_id bigint NULL,
    is_active boolean DEFAULT true NOT NULL,
    sort_order integer DEFAULT 0 NOT NULL,
    created_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_by bigint NULL,
    updated_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_by bigint NULL,
    CONSTRAINT uq_company_size_band_code UNIQUE (code),
    CONSTRAINT chk_company_size_band_code CHECK (code ~ '^[a-z][a-z0-9_]*$'),
    CONSTRAINT chk_company_size_band_sort_order CHECK (sort_order >= 0)
);

CREATE TABLE organisation.account_type (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    code varchar(50) NOT NULL,
    ui_label_id bigint NULL,
    is_active boolean DEFAULT true NOT NULL,
    sort_order integer DEFAULT 0 NOT NULL,
    created_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_by bigint NULL,
    updated_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_by bigint NULL,
    CONSTRAINT uq_account_type_code UNIQUE (code),
    CONSTRAINT chk_account_type_code CHECK (code ~ '^[a-z][a-z0-9_]*$'),
    CONSTRAINT chk_account_type_sort_order CHECK (sort_order >= 0)
);

CREATE TABLE organisation.account_status (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    code varchar(50) NOT NULL,
    ui_label_id bigint NULL,
    is_active boolean DEFAULT true NOT NULL,
    sort_order integer DEFAULT 0 NOT NULL,
    created_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_by bigint NULL,
    updated_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_by bigint NULL,
    CONSTRAINT uq_account_status_code UNIQUE (code),
    CONSTRAINT chk_account_status_code CHECK (code ~ '^[a-z][a-z0-9_]*$'),
    CONSTRAINT chk_account_status_sort_order CHECK (sort_order >= 0)
);

CREATE TABLE organisation.verification_type (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    code varchar(50) NOT NULL,
    ui_label_id bigint NULL,
    is_active boolean DEFAULT true NOT NULL,
    sort_order integer DEFAULT 0 NOT NULL,
    created_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_by bigint NULL,
    updated_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_by bigint NULL,
    CONSTRAINT uq_verification_type_code UNIQUE (code),
    CONSTRAINT chk_verification_type_code CHECK (code ~ '^[a-z][a-z0-9_]*$'),
    CONSTRAINT chk_verification_type_sort_order CHECK (sort_order >= 0)
);

CREATE TABLE organisation.verification_provider (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    code varchar(50) NOT NULL,
    ui_label_id bigint NULL,
    is_active boolean DEFAULT true NOT NULL,
    sort_order integer DEFAULT 0 NOT NULL,
    created_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_by bigint NULL,
    updated_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_by bigint NULL,
    CONSTRAINT uq_verification_provider_code UNIQUE (code),
    CONSTRAINT chk_verification_provider_code CHECK (code ~ '^[a-z][a-z0-9_]*$'),
    CONSTRAINT chk_verification_provider_sort_order CHECK (sort_order >= 0)
);

CREATE TABLE organisation.verification_status (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    code varchar(50) NOT NULL,
    ui_label_id bigint NULL,
    is_active boolean DEFAULT true NOT NULL,
    sort_order integer DEFAULT 0 NOT NULL,
    created_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_by bigint NULL,
    updated_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_by bigint NULL,
    CONSTRAINT uq_verification_status_code UNIQUE (code),
    CONSTRAINT chk_verification_status_code CHECK (code ~ '^[a-z][a-z0-9_]*$'),
    CONSTRAINT chk_verification_status_sort_order CHECK (sort_order >= 0)
);

CREATE TABLE organisation.audit_action (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    code varchar(50) NOT NULL,
    ui_label_id bigint NULL,
    is_active boolean DEFAULT true NOT NULL,
    sort_order integer DEFAULT 0 NOT NULL,
    created_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_by bigint NULL,
    updated_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_by bigint NULL,
    CONSTRAINT uq_audit_action_code UNIQUE (code),
    CONSTRAINT chk_audit_action_code CHECK (code ~ '^[a-z][a-z0-9_]*$'),
    CONSTRAINT chk_audit_action_sort_order CHECK (sort_order >= 0)
);

CREATE TABLE organisation.identifier_type (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    code varchar(50) NOT NULL,
    country_id bigint NULL,
    validation_pattern varchar(200) NULL,
    ui_label_id bigint NULL,
    is_active boolean DEFAULT true NOT NULL,
    sort_order integer DEFAULT 0 NOT NULL,
    created_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_by bigint NULL,
    updated_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_by bigint NULL,
    CONSTRAINT fk_identifier_type_country_id FOREIGN KEY (country_id)
        REFERENCES master_data.country(id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT uq_identifier_type_code UNIQUE (code),
    CONSTRAINT chk_identifier_type_code CHECK (code ~ '^[a-z][a-z0-9_]*$'),
    CONSTRAINT chk_identifier_type_sort_order CHECK (sort_order >= 0)
);

CREATE TABLE organisation.organisation_relationship_type (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    code varchar(50) NOT NULL,
    is_hierarchical boolean DEFAULT false NOT NULL,
    ui_label_id bigint NULL,
    is_active boolean DEFAULT true NOT NULL,
    sort_order integer DEFAULT 0 NOT NULL,
    created_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_by bigint NULL,
    updated_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_by bigint NULL,
    CONSTRAINT uq_organisation_relationship_type_code UNIQUE (code),
    CONSTRAINT chk_organisation_relationship_type_code CHECK (code ~ '^[a-z][a-z0-9_]*$'),
    CONSTRAINT chk_organisation_relationship_type_sort_order CHECK (sort_order >= 0)
);

CREATE TABLE organisation.verification_status_transition (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    from_verification_status_id bigint NOT NULL,
    to_verification_status_id bigint NOT NULL,
    created_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_by bigint NULL,
    CONSTRAINT fk_verif_transition_from FOREIGN KEY (from_verification_status_id)
        REFERENCES organisation.verification_status(id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_verif_transition_to FOREIGN KEY (to_verification_status_id)
        REFERENCES organisation.verification_status(id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT uq_verif_transition_pair UNIQUE (from_verification_status_id, to_verification_status_id),
    CONSTRAINT chk_verif_transition_distinct CHECK (from_verification_status_id <> to_verification_status_id)
);


-- ============================================================================
-- 2. CORE ORGANISATION & ACCOUNT ENTITIES
-- ============================================================================

-- 2.1 Organisation (Employer / Client Profile)
CREATE TABLE organisation.organisation (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    organisation_name varchar(255) NOT NULL,
    legal_name varchar(255) NULL,
    organisation_type_id bigint NOT NULL,
    industry_id bigint NULL,
    company_size_band_id bigint NULL,
    founded_year smallint NULL,
    website_url varchar(2048) NULL,
    contact_email varchar(254) NULL,
    contact_phone_e164 varchar(16) NULL,
    contact_phone_country_id bigint NULL,
    description varchar(4000) NULL,
    description_language_id bigint NULL,
    logo_uri varchar(2048) NULL,
    organisation_status_id bigint NOT NULL,
    created_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_by bigint NOT NULL,
    updated_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_by bigint NOT NULL,
    deleted_at timestamptz NULL,
    deleted_by bigint NULL,
    CONSTRAINT fk_organisation_type_id FOREIGN KEY (organisation_type_id)
        REFERENCES organisation.organisation_type(id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_organisation_industry_id FOREIGN KEY (industry_id)
        REFERENCES master_data.industry(id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_organisation_company_size_band_id FOREIGN KEY (company_size_band_id)
        REFERENCES organisation.company_size_band(id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_organisation_contact_phone_country_id FOREIGN KEY (contact_phone_country_id)
        REFERENCES master_data.country(id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_organisation_description_language_id FOREIGN KEY (description_language_id)
        REFERENCES master_data.language(id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_organisation_status_id FOREIGN KEY (organisation_status_id)
        REFERENCES organisation.organisation_status(id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_organisation_created_by FOREIGN KEY (created_by)
        REFERENCES administration.user_account(id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_organisation_updated_by FOREIGN KEY (updated_by)
        REFERENCES administration.user_account(id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_organisation_deleted_by FOREIGN KEY (deleted_by)
        REFERENCES administration.user_account(id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT chk_organisation_name_not_empty CHECK (length(trim(organisation_name)) > 0),
    CONSTRAINT chk_organisation_founded_year CHECK (founded_year IS NULL OR (founded_year >= 1800 AND founded_year <= 2100)),
    CONSTRAINT chk_organisation_website_url CHECK (website_url IS NULL OR website_url ~* '^https?://'),
    CONSTRAINT chk_organisation_contact_email CHECK (contact_email IS NULL OR contact_email = lower(contact_email)),
    CONSTRAINT chk_organisation_contact_phone CHECK (
        (contact_phone_e164 IS NULL AND contact_phone_country_id IS NULL) OR
        (contact_phone_e164 ~ '^\+[1-9][0-9]{6,14}$' AND contact_phone_country_id IS NOT NULL)
    ),
    CONSTRAINT chk_organisation_soft_delete CHECK ((deleted_at IS NULL) = (deleted_by IS NULL))
);

-- 2.2 Account (Platform Tenant Account)
CREATE TABLE organisation.account (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    organisation_id bigint NOT NULL,
    account_name varchar(255) NOT NULL,
    account_type_id bigint NOT NULL,
    account_status_id bigint NOT NULL,
    created_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_by bigint NOT NULL,
    updated_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_by bigint NOT NULL,
    deleted_at timestamptz NULL,
    deleted_by bigint NULL,
    CONSTRAINT fk_account_organisation_id FOREIGN KEY (organisation_id)
        REFERENCES organisation.organisation(id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_account_type_id FOREIGN KEY (account_type_id)
        REFERENCES organisation.account_type(id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_account_status_id FOREIGN KEY (account_status_id)
        REFERENCES organisation.account_status(id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_account_created_by FOREIGN KEY (created_by)
        REFERENCES administration.user_account(id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_account_updated_by FOREIGN KEY (updated_by)
        REFERENCES administration.user_account(id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_account_deleted_by FOREIGN KEY (deleted_by)
        REFERENCES administration.user_account(id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT chk_account_name_not_empty CHECK (length(trim(account_name)) > 0),
    CONSTRAINT chk_account_soft_delete CHECK ((deleted_at IS NULL) = (deleted_by IS NULL))
);

-- One live account per organisation
CREATE UNIQUE INDEX uq_account_organisation_id 
    ON organisation.account (organisation_id) 
    WHERE deleted_at IS NULL;

-- 2.3 Account Administrator (End-dated tenure mapping)
CREATE TABLE organisation.account_administrator (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    account_id bigint NOT NULL,
    app_user_id bigint NOT NULL,
    assigned_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    ended_at timestamptz NULL,
    created_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_by bigint NOT NULL,
    updated_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_by bigint NOT NULL,
    CONSTRAINT fk_account_administrator_account_id FOREIGN KEY (account_id)
        REFERENCES organisation.account(id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_account_administrator_app_user_id FOREIGN KEY (app_user_id)
        REFERENCES administration.user_account(id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_account_administrator_created_by FOREIGN KEY (created_by)
        REFERENCES administration.user_account(id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_account_administrator_updated_by FOREIGN KEY (updated_by)
        REFERENCES administration.user_account(id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT chk_account_administrator_ended_at CHECK (ended_at IS NULL OR ended_at >= assigned_at),
    CONSTRAINT ex_account_administrator_overlap EXCLUDE USING gist (
        account_id WITH =,
        app_user_id WITH =,
        tstzrange(assigned_at, ended_at) WITH &&
    )
);

-- 2.4 Organisation Location (Offices & Headquarters)
CREATE TABLE organisation.organisation_location (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    organisation_id bigint NOT NULL,
    location_name varchar(150) NOT NULL,
    address_line_1 varchar(200) NOT NULL,
    address_line_2 varchar(200) NULL,
    country_id bigint NOT NULL,
    state_id bigint NULL,
    city_id bigint NULL,
    postal_code varchar(20) NULL,
    phone_e164 varchar(16) NULL,
    phone_country_id bigint NULL,
    latitude numeric(9,6) NULL,
    longitude numeric(9,6) NULL,
    place_reference varchar(100) NULL,
    is_headquarters boolean DEFAULT false NOT NULL,
    created_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_by bigint NOT NULL,
    updated_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_by bigint NOT NULL,
    deleted_at timestamptz NULL,
    deleted_by bigint NULL,
    CONSTRAINT fk_organisation_location_organisation_id FOREIGN KEY (organisation_id)
        REFERENCES organisation.organisation(id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_organisation_location_country_id FOREIGN KEY (country_id)
        REFERENCES master_data.country(id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_organisation_location_state_id FOREIGN KEY (state_id)
        REFERENCES master_data.state(id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_organisation_location_city_id FOREIGN KEY (city_id)
        REFERENCES master_data.city(id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_organisation_location_phone_country_id FOREIGN KEY (phone_country_id)
        REFERENCES master_data.country(id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_organisation_location_created_by FOREIGN KEY (created_by)
        REFERENCES administration.user_account(id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_organisation_location_updated_by FOREIGN KEY (updated_by)
        REFERENCES administration.user_account(id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_organisation_location_deleted_by FOREIGN KEY (deleted_by)
        REFERENCES administration.user_account(id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT chk_organisation_location_phone CHECK (
        (phone_e164 IS NULL AND phone_country_id IS NULL) OR
        (phone_e164 ~ '^\+[1-9][0-9]{6,14}$' AND phone_country_id IS NOT NULL)
    ),
    CONSTRAINT chk_organisation_location_geo CHECK (
        (latitude IS NULL AND longitude IS NULL) OR
        (latitude BETWEEN -90.0 AND 90.0 AND longitude BETWEEN -180.0 AND 180.0)
    ),
    CONSTRAINT chk_organisation_location_soft_delete CHECK ((deleted_at IS NULL) = (deleted_by IS NULL))
);

-- Exactly one live headquarters per organisation
CREATE UNIQUE INDEX uq_organisation_location_headquarters 
    ON organisation.organisation_location (organisation_id) 
    WHERE is_headquarters = true AND deleted_at IS NULL;

-- 2.5 Organisation Identifier (Encrypted Tax & Registration IDs)
CREATE TABLE organisation.organisation_identifier (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    organisation_id bigint NOT NULL,
    identifier_type_id bigint NOT NULL,
    country_id bigint NOT NULL,
    identifier_value_encrypted text NOT NULL, -- AES-256-GCM envelope, base64
    identifier_fingerprint char(64) NOT NULL, -- HMAC-SHA256 hex
    identifier_key_version smallint NOT NULL,
    identifier_masked varchar(20) NOT NULL, -- e.g. ***********1Z5
    created_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_by bigint NOT NULL,
    updated_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_by bigint NOT NULL,
    deleted_at timestamptz NULL,
    deleted_by bigint NULL,
    CONSTRAINT fk_org_identifier_org FOREIGN KEY (organisation_id)
        REFERENCES organisation.organisation(id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_org_identifier_type FOREIGN KEY (identifier_type_id)
        REFERENCES organisation.identifier_type(id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_org_identifier_country FOREIGN KEY (country_id)
        REFERENCES master_data.country(id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_org_identifier_created_by FOREIGN KEY (created_by)
        REFERENCES administration.user_account(id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_org_identifier_updated_by FOREIGN KEY (updated_by)
        REFERENCES administration.user_account(id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_org_identifier_deleted_by FOREIGN KEY (deleted_by)
        REFERENCES administration.user_account(id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT uq_organisation_identifier_pair UNIQUE (id, organisation_id),
    CONSTRAINT chk_org_identifier_key_version CHECK (identifier_key_version > 0),
    CONSTRAINT chk_org_identifier_soft_delete CHECK ((deleted_at IS NULL) = (deleted_by IS NULL))
);

CREATE UNIQUE INDEX uq_organisation_identifier_fingerprint 
    ON organisation.organisation_identifier (identifier_type_id, country_id, identifier_fingerprint) 
    WHERE deleted_at IS NULL;

-- 2.6 Organisation Domain (Verified Web Domains)
CREATE TABLE organisation.organisation_domain (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    organisation_id bigint NOT NULL,
    domain_name varchar(253) NOT NULL,
    is_primary boolean DEFAULT false NOT NULL,
    verification_token_hash char(64) NULL,
    created_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_by bigint NOT NULL,
    updated_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_by bigint NOT NULL,
    deleted_at timestamptz NULL,
    deleted_by bigint NULL,
    CONSTRAINT fk_org_domain_org FOREIGN KEY (organisation_id)
        REFERENCES organisation.organisation(id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_org_domain_created_by FOREIGN KEY (created_by)
        REFERENCES administration.user_account(id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_org_domain_updated_by FOREIGN KEY (updated_by)
        REFERENCES administration.user_account(id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_org_domain_deleted_by FOREIGN KEY (deleted_by)
        REFERENCES administration.user_account(id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT uq_organisation_domain_pair UNIQUE (id, organisation_id),
    CONSTRAINT chk_org_domain_lower CHECK (domain_name = lower(domain_name)),
    CONSTRAINT chk_org_domain_soft_delete CHECK ((deleted_at IS NULL) = (deleted_by IS NULL))
);

CREATE UNIQUE INDEX uq_organisation_domain_name 
    ON organisation.organisation_domain (domain_name) 
    WHERE deleted_at IS NULL;

CREATE UNIQUE INDEX uq_organisation_domain_primary 
    ON organisation.organisation_domain (organisation_id) 
    WHERE is_primary = true AND deleted_at IS NULL;

-- 2.7 Organisation Verification (Stateful Verification Request Ledger)
CREATE TABLE organisation.organisation_verification (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    organisation_id bigint NOT NULL,
    organisation_identifier_id bigint NULL,
    organisation_domain_id bigint NULL,
    verification_type_id bigint NOT NULL,
    verification_provider_id bigint NULL,
    verification_status_id bigint NOT NULL,
    idempotency_key uuid DEFAULT gen_random_uuid() NOT NULL,
    provider_reference varchar(100) NULL,
    retry_count smallint DEFAULT 0 NOT NULL,
    next_retry_at timestamptz NULL,
    last_error_code varchar(50) NULL,
    verified_at timestamptz NULL,
    expires_at timestamptz NULL,
    created_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_by bigint NOT NULL,
    updated_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_by bigint NOT NULL,
    CONSTRAINT fk_org_verif_org FOREIGN KEY (organisation_id)
        REFERENCES organisation.organisation(id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_org_verif_identifier_composite FOREIGN KEY (organisation_identifier_id, organisation_id)
        REFERENCES organisation.organisation_identifier(id, organisation_id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_org_verif_domain_composite FOREIGN KEY (organisation_domain_id, organisation_id)
        REFERENCES organisation.organisation_domain(id, organisation_id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_org_verif_type FOREIGN KEY (verification_type_id)
        REFERENCES organisation.verification_type(id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_org_verif_provider FOREIGN KEY (verification_provider_id)
        REFERENCES organisation.verification_provider(id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_org_verif_status FOREIGN KEY (verification_status_id)
        REFERENCES organisation.verification_status(id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_org_verif_created_by FOREIGN KEY (created_by)
        REFERENCES administration.user_account(id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_org_verif_updated_by FOREIGN KEY (updated_by)
        REFERENCES administration.user_account(id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT uq_org_verif_idempotency UNIQUE (idempotency_key),
    CONSTRAINT chk_org_verif_subject CHECK (
        (organisation_identifier_id IS NOT NULL AND organisation_domain_id IS NULL) OR
        (organisation_identifier_id IS NULL AND organisation_domain_id IS NOT NULL) OR
        (organisation_identifier_id IS NULL AND organisation_domain_id IS NULL)
    ),
    CONSTRAINT chk_org_verif_retry_count CHECK (retry_count >= 0),
    CONSTRAINT chk_org_verif_expiry CHECK (expires_at IS NULL OR (verified_at IS NOT NULL AND expires_at > verified_at))
);

-- 2.8 Organisation Verification History (Append-only status changes)
CREATE TABLE organisation.organisation_verification_history (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    organisation_verification_id bigint NOT NULL,
    previous_status_id bigint NULL,
    new_status_id bigint NOT NULL,
    changed_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    changed_by bigint NOT NULL,
    reason varchar(500) NULL,
    CONSTRAINT fk_org_verif_hist_verif FOREIGN KEY (organisation_verification_id)
        REFERENCES organisation.organisation_verification(id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_org_verif_hist_prev_status FOREIGN KEY (previous_status_id)
        REFERENCES organisation.verification_status(id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_org_verif_hist_new_status FOREIGN KEY (new_status_id)
        REFERENCES organisation.verification_status(id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_org_verif_hist_changed_by FOREIGN KEY (changed_by)
        REFERENCES administration.user_account(id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT chk_org_verif_hist_distinct CHECK (previous_status_id IS NULL OR previous_status_id <> new_status_id)
);

-- 2.9 Organisation Recruiter (Effective-dated Recruiter Mapping)
CREATE TABLE organisation.organisation_recruiter (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    organisation_id bigint NOT NULL,
    app_user_id bigint NOT NULL,
    assignment_start_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    assignment_end_at timestamptz NULL,
    created_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_by bigint NOT NULL,
    updated_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_by bigint NOT NULL,
    CONSTRAINT fk_org_recruiter_org FOREIGN KEY (organisation_id)
        REFERENCES organisation.organisation(id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_org_recruiter_app_user FOREIGN KEY (app_user_id)
        REFERENCES administration.user_account(id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_org_recruiter_created_by FOREIGN KEY (created_by)
        REFERENCES administration.user_account(id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_org_recruiter_updated_by FOREIGN KEY (updated_by)
        REFERENCES administration.user_account(id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT chk_org_recruiter_end_at CHECK (assignment_end_at IS NULL OR assignment_end_at >= assignment_start_at),
    CONSTRAINT ex_organisation_recruiter_overlap EXCLUDE USING gist (
        organisation_id WITH =,
        app_user_id WITH =,
        tstzrange(assignment_start_at, assignment_end_at) WITH &&
    )
);

-- 2.10 Recruiter Assignment History (Append-only assignment log)
CREATE TABLE organisation.recruiter_assignment_history (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    organisation_recruiter_id bigint NOT NULL,
    audit_action_id bigint NOT NULL,
    previous_assignment_start_at timestamptz NULL,
    previous_assignment_end_at timestamptz NULL,
    new_assignment_start_at timestamptz NOT NULL,
    new_assignment_end_at timestamptz NULL,
    changed_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    changed_by bigint NOT NULL,
    reason varchar(500) NULL,
    CONSTRAINT fk_recruiter_hist_recruiter FOREIGN KEY (organisation_recruiter_id)
        REFERENCES organisation.organisation_recruiter(id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_recruiter_hist_action FOREIGN KEY (audit_action_id)
        REFERENCES organisation.audit_action(id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_recruiter_hist_changed_by FOREIGN KEY (changed_by)
        REFERENCES administration.user_account(id) ON UPDATE RESTRICT ON DELETE RESTRICT
);

-- 2.11 Organisation Relationship (Hierarchies, Subsidiaries, Franchises)
CREATE TABLE organisation.organisation_relationship (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    parent_organisation_id bigint NOT NULL,
    child_organisation_id bigint NOT NULL,
    organisation_relationship_type_id bigint NOT NULL,
    effective_from date NOT NULL,
    effective_to date NULL,
    created_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_by bigint NOT NULL,
    updated_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_by bigint NOT NULL,
    CONSTRAINT fk_org_rel_parent FOREIGN KEY (parent_organisation_id)
        REFERENCES organisation.organisation(id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_org_rel_child FOREIGN KEY (child_organisation_id)
        REFERENCES organisation.organisation(id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_org_rel_type FOREIGN KEY (organisation_relationship_type_id)
        REFERENCES organisation.organisation_relationship_type(id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_org_rel_created_by FOREIGN KEY (created_by)
        REFERENCES administration.user_account(id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_org_rel_updated_by FOREIGN KEY (updated_by)
        REFERENCES administration.user_account(id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT chk_org_rel_not_self CHECK (parent_organisation_id <> child_organisation_id),
    CONSTRAINT chk_org_rel_dates CHECK (effective_to IS NULL OR effective_to >= effective_from),
    CONSTRAINT ex_organisation_relationship_overlap EXCLUDE USING gist (
        child_organisation_id WITH =,
        organisation_relationship_type_id WITH =,
        daterange(effective_from, effective_to) WITH &&
    )
);


-- ============================================================================
-- 3. AUDIT TRAIL TABLE (Range-Partitioned by Month)
-- ============================================================================
CREATE TABLE organisation.audit_event (
    id bigint GENERATED ALWAYS AS IDENTITY,
    occurred_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    audit_action_id bigint NOT NULL,
    actor_id bigint NOT NULL,
    entity_name varchar(63) NOT NULL,
    entity_id bigint NULL,
    organisation_id bigint NULL,
    is_success boolean DEFAULT true NOT NULL,
    request_id uuid NULL,
    ip_address inet NULL,
    before_data jsonb NULL,
    after_data jsonb NULL,
    reason varchar(500) NULL,
    CONSTRAINT pk_audit_event PRIMARY KEY (id, occurred_at),
    CONSTRAINT fk_audit_event_action FOREIGN KEY (audit_action_id)
        REFERENCES organisation.audit_action(id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_audit_event_actor FOREIGN KEY (actor_id)
        REFERENCES administration.user_account(id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_audit_event_org FOREIGN KEY (organisation_id)
        REFERENCES organisation.organisation(id) ON UPDATE RESTRICT ON DELETE RESTRICT
) PARTITION BY RANGE (occurred_at);

-- Pre-create default partition and monthly partitions for 2026/2027
CREATE TABLE organisation.audit_event_p_default PARTITION OF organisation.audit_event DEFAULT;

CREATE TABLE organisation.audit_event_p202610 PARTITION OF organisation.audit_event
    FOR VALUES FROM ('2026-10-01 00:00:00+00') TO ('2026-11-01 00:00:00+00');
CREATE TABLE organisation.audit_event_p202611 PARTITION OF organisation.audit_event
    FOR VALUES FROM ('2026-11-01 00:00:00+00') TO ('2026-12-01 00:00:00+00');
CREATE TABLE organisation.audit_event_p202612 PARTITION OF organisation.audit_event
    FOR VALUES FROM ('2026-12-01 00:00:00+00') TO ('2027-01-01 00:00:00+00');
CREATE TABLE organisation.audit_event_p202701 PARTITION OF organisation.audit_event
    FOR VALUES FROM ('2027-01-01 00:00:00+00') TO ('2027-02-01 00:00:00+00');
CREATE TABLE organisation.audit_event_p202702 PARTITION OF organisation.audit_event
    FOR VALUES FROM ('2027-02-01 00:00:00+00') TO ('2027-03-01 00:00:00+00');
CREATE TABLE organisation.audit_event_p202703 PARTITION OF organisation.audit_event
    FOR VALUES FROM ('2027-03-01 00:00:00+00') TO ('2027-04-01 00:00:00+00');

-- Dynamic partition creator function (Section 7)
CREATE OR REPLACE FUNCTION organisation.fn_create_audit_event_partition(p_month date)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_partition_name text;
    v_start_date text;
    v_end_date text;
BEGIN
    v_partition_name := 'audit_event_p' || to_char(p_month, 'YYYYMM');
    v_start_date := to_char(date_trunc('month', p_month), 'YYYY-MM-DD 00:00:00+00');
    v_end_date := to_char(date_trunc('month', p_month + INTERVAL '1 month'), 'YYYY-MM-DD 00:00:00+00');

    EXECUTE format(
        'CREATE TABLE IF NOT EXISTS organisation.%I PARTITION OF organisation.audit_event
         FOR VALUES FROM (%L) TO (%L)',
        v_partition_name, v_start_date, v_end_date
    );
END;
$$;


-- ============================================================================
-- 4. AUTOMATED TRIGGERS & INTEGRITY PROCEDURES
-- ============================================================================

-- updated_at triggers
CREATE TRIGGER trg_organisation_updated_at BEFORE UPDATE ON organisation.organisation
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_account_updated_at BEFORE UPDATE ON organisation.account
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_account_administrator_updated_at BEFORE UPDATE ON organisation.account_administrator
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_organisation_location_updated_at BEFORE UPDATE ON organisation.organisation_location
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_organisation_identifier_updated_at BEFORE UPDATE ON organisation.organisation_identifier
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_organisation_domain_updated_at BEFORE UPDATE ON organisation.organisation_domain
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_organisation_verification_updated_at BEFORE UPDATE ON organisation.organisation_verification
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_organisation_recruiter_updated_at BEFORE UPDATE ON organisation.organisation_recruiter
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_organisation_relationship_updated_at BEFORE UPDATE ON organisation.organisation_relationship
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- Append-only enforcement on history tables and audit log
CREATE TRIGGER trg_org_verif_hist_append_only BEFORE UPDATE OR DELETE ON organisation.organisation_verification_history
FOR EACH ROW EXECUTE FUNCTION enforce_append_only();

CREATE TRIGGER trg_recruiter_hist_append_only BEFORE UPDATE OR DELETE ON organisation.recruiter_assignment_history
FOR EACH ROW EXECUTE FUNCTION enforce_append_only();

CREATE TRIGGER trg_audit_event_append_only BEFORE UPDATE OR DELETE ON organisation.audit_event
FOR EACH ROW EXECUTE FUNCTION enforce_append_only();

-- Hierarchy cycle prevention trigger for hierarchical relationship types
CREATE OR REPLACE FUNCTION organisation.check_hierarchy_cycle()
RETURNS TRIGGER AS $$
DECLARE
    v_is_hierarchical boolean;
    v_cycle_detected boolean;
BEGIN
    SELECT is_hierarchical INTO v_is_hierarchical
    FROM organisation.organisation_relationship_type
    WHERE id = NEW.organisation_relationship_type_id;

    IF (v_is_hierarchical = true) THEN
        -- Acquire transaction-level advisory lock to serialize concurrent cycle checks
        PERFORM pg_advisory_xact_lock(hashtext('organisation_hierarchy_lock'));

        WITH RECURSIVE ancestor_tree AS (
            -- Base case: the proposed parent
            SELECT parent_organisation_id, child_organisation_id
            FROM organisation.organisation_relationship
            WHERE child_organisation_id = NEW.parent_organisation_id
              AND organisation_relationship_type_id = NEW.organisation_relationship_type_id
              AND (effective_to IS NULL OR effective_to >= NEW.effective_from)
              AND (NEW.effective_to IS NULL OR effective_from <= NEW.effective_to)
            UNION ALL
            -- Recursive step: traverse upwards
            SELECT r.parent_organisation_id, r.child_organisation_id
            FROM organisation.organisation_relationship r
            JOIN ancestor_tree a ON r.child_organisation_id = a.parent_organisation_id
            WHERE r.organisation_relationship_type_id = NEW.organisation_relationship_type_id
              AND (r.effective_to IS NULL OR r.effective_to >= NEW.effective_from)
              AND (NEW.effective_to IS NULL OR r.effective_from <= NEW.effective_to)
        )
        SELECT EXISTS (
            SELECT 1 FROM ancestor_tree WHERE parent_organisation_id = NEW.child_organisation_id
        ) INTO v_cycle_detected;

        IF (v_cycle_detected = true) THEN
            RAISE EXCEPTION 'Hierarchy cycle detected: organisation % is already an ancestor of %',
                NEW.child_organisation_id, NEW.parent_organisation_id
                USING ERRCODE = '23514';
        END IF;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_organisation_relationship_cycle
BEFORE INSERT OR UPDATE ON organisation.organisation_relationship
FOR EACH ROW EXECUTE FUNCTION organisation.check_hierarchy_cycle();

-- Verification state transition guard trigger
CREATE OR REPLACE FUNCTION organisation.guard_verification_transition()
RETURNS TRIGGER AS $$
DECLARE
    v_verified_status_id bigint;
    v_valid_transition boolean;
BEGIN
    SELECT id INTO v_verified_status_id
    FROM organisation.verification_status WHERE code = 'verified';

    -- Mandate verified_at when moving to 'verified'
    IF (NEW.verification_status_id = v_verified_status_id AND NEW.verified_at IS NULL) THEN
        NEW.verified_at = CURRENT_TIMESTAMP;
    END IF;

    -- On UPDATE of status, validate against transition table
    IF (TG_OP = 'UPDATE' AND OLD.verification_status_id <> NEW.verification_status_id) THEN
        SELECT EXISTS (
            SELECT 1 FROM organisation.verification_status_transition
            WHERE from_verification_status_id = OLD.verification_status_id
              AND to_verification_status_id = NEW.verification_status_id
        ) INTO v_valid_transition;

        IF (NOT v_valid_transition) THEN
            RAISE EXCEPTION 'Illegal verification status transition from % to %',
                OLD.verification_status_id, NEW.verification_status_id
                USING ERRCODE = '23514';
        END IF;

        -- Record verification history automatically in the same transaction
        INSERT INTO organisation.organisation_verification_history (
            organisation_verification_id, previous_status_id, new_status_id, changed_by, reason
        ) VALUES (
            NEW.id, OLD.verification_status_id, NEW.verification_status_id, NEW.updated_by, 'Status transition'
        );
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_guard_verification_transition
BEFORE UPDATE OF verification_status_id ON organisation.organisation_verification
FOR EACH ROW EXECUTE FUNCTION organisation.guard_verification_transition();

-- Assert user holds required role (recruiter or account_admin)
CREATE OR REPLACE FUNCTION organisation.fn_assert_user_role()
RETURNS TRIGGER AS $$
DECLARE
    v_has_role boolean;
    v_required_role varchar(50);
BEGIN
    IF TG_TABLE_NAME = 'organisation_recruiter' THEN
        v_required_role := 'recruiter';
    ELSIF TG_TABLE_NAME = 'account_administrator' THEN
        v_required_role := 'account_admin';
    END IF;

    SELECT EXISTS (
        SELECT 1 FROM administration.user_role ur
        JOIN administration.role r ON r.id = ur.role_id
        WHERE ur.user_account_id = NEW.app_user_id
          AND r.code IN (v_required_role, 'super_admin')
    ) INTO v_has_role;

    IF NOT v_has_role THEN
        RAISE EXCEPTION 'User % does not possess mandatory % role',
            NEW.app_user_id, v_required_role
            USING ERRCODE = '23514';
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_assert_recruiter_role
BEFORE INSERT OR UPDATE OF app_user_id ON organisation.organisation_recruiter
FOR EACH ROW EXECUTE FUNCTION organisation.fn_assert_user_role();

CREATE TRIGGER trg_assert_admin_role
BEFORE INSERT OR UPDATE OF app_user_id ON organisation.account_administrator
FOR EACH ROW EXECUTE FUNCTION organisation.fn_assert_user_role();

-- Recruiter assignment history capture trigger
CREATE OR REPLACE FUNCTION organisation.fn_recruiter_history()
RETURNS TRIGGER AS $$
DECLARE
    v_action_id bigint;
    v_actor_id bigint;
    v_reason varchar(500);
BEGIN
    v_actor_id := coalesce(nullif(current_setting('app.current_user_id', true), '')::bigint, 1000);
    v_reason := nullif(current_setting('app.change_reason', true), '');

    IF TG_OP = 'INSERT' THEN
        SELECT id INTO v_action_id FROM organisation.audit_action WHERE code = 'recruiter_assigned';
        INSERT INTO organisation.recruiter_assignment_history (
            organisation_recruiter_id, audit_action_id,
            previous_assignment_start_at, previous_assignment_end_at,
            new_assignment_start_at, new_assignment_end_at,
            changed_by, reason
        ) VALUES (
            NEW.id, v_action_id,
            NULL, NULL,
            NEW.assignment_start_at, NEW.assignment_end_at,
            coalesce(NEW.created_by, v_actor_id), v_reason
        );
    ELSIF TG_OP = 'UPDATE' THEN
        IF NEW.assignment_end_at IS NOT NULL AND (OLD.assignment_end_at IS NULL OR OLD.assignment_end_at <> NEW.assignment_end_at) THEN
            SELECT id INTO v_action_id FROM organisation.audit_action WHERE code = 'recruiter_unassigned';
        ELSE
            SELECT id INTO v_action_id FROM organisation.audit_action WHERE code = 'recruiter_assignment_changed';
        END IF;

        INSERT INTO organisation.recruiter_assignment_history (
            organisation_recruiter_id, audit_action_id,
            previous_assignment_start_at, previous_assignment_end_at,
            new_assignment_start_at, new_assignment_end_at,
            changed_by, reason
        ) VALUES (
            NEW.id, v_action_id,
            OLD.assignment_start_at, OLD.assignment_end_at,
            NEW.assignment_start_at, NEW.assignment_end_at,
            coalesce(NEW.updated_by, v_actor_id), v_reason
        );
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_recruiter_history
AFTER INSERT OR UPDATE ON organisation.organisation_recruiter
FOR EACH ROW EXECUTE FUNCTION organisation.fn_recruiter_history();

-- Hard delete blocking trigger (Enforces soft-delete unless retention job is running)
CREATE OR REPLACE FUNCTION organisation.fn_block_delete()
RETURNS TRIGGER AS $$
BEGIN
    IF current_setting('app.retention_job', true) = 'on' THEN
        RETURN OLD;
    END IF;

    RAISE EXCEPTION 'Hard delete forbidden on %: soft delete required (set deleted_at / deleted_by)', TG_TABLE_NAME
        USING ERRCODE = '23514';
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_block_delete_organisation
BEFORE DELETE ON organisation.organisation
FOR EACH ROW EXECUTE FUNCTION organisation.fn_block_delete();

CREATE TRIGGER trg_block_delete_account
BEFORE DELETE ON organisation.account
FOR EACH ROW EXECUTE FUNCTION organisation.fn_block_delete();

CREATE TRIGGER trg_block_delete_location
BEFORE DELETE ON organisation.organisation_location
FOR EACH ROW EXECUTE FUNCTION organisation.fn_block_delete();

CREATE TRIGGER trg_block_delete_identifier
BEFORE DELETE ON organisation.organisation_identifier
FOR EACH ROW EXECUTE FUNCTION organisation.fn_block_delete();

CREATE TRIGGER trg_block_delete_domain
BEFORE DELETE ON organisation.organisation_domain
FOR EACH ROW EXECUTE FUNCTION organisation.fn_block_delete();

-- Audit columns protection trigger (created_* cannot be forged or mutated)
CREATE OR REPLACE FUNCTION organisation.fn_set_audit_columns()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'UPDATE' THEN
        NEW.created_at := OLD.created_at;
        NEW.created_by := OLD.created_by;
        NEW.updated_at := CURRENT_TIMESTAMP;
        NEW.updated_by := coalesce(nullif(current_setting('app.current_user_id', true), '')::bigint, NEW.updated_by, OLD.updated_by);
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_set_audit_cols_organisation
BEFORE UPDATE ON organisation.organisation
FOR EACH ROW EXECUTE FUNCTION organisation.fn_set_audit_columns();

CREATE TRIGGER trg_set_audit_cols_account
BEFORE UPDATE ON organisation.account
FOR EACH ROW EXECUTE FUNCTION organisation.fn_set_audit_columns();

CREATE TRIGGER trg_set_audit_cols_location
BEFORE UPDATE ON organisation.organisation_location
FOR EACH ROW EXECUTE FUNCTION organisation.fn_set_audit_columns();

CREATE TRIGGER trg_set_audit_cols_identifier
BEFORE UPDATE ON organisation.organisation_identifier
FOR EACH ROW EXECUTE FUNCTION organisation.fn_set_audit_columns();

CREATE TRIGGER trg_set_audit_cols_domain
BEFORE UPDATE ON organisation.organisation_domain
FOR EACH ROW EXECUTE FUNCTION organisation.fn_set_audit_columns();

-- Central Security Definer Audit Writer Function (Section 7)
CREATE OR REPLACE FUNCTION organisation.fn_audit_log(
    p_audit_action_code varchar(50),
    p_entity_name varchar(63),
    p_entity_id bigint DEFAULT NULL,
    p_organisation_id bigint DEFAULT NULL,
    p_is_success boolean DEFAULT true,
    p_before_data jsonb DEFAULT NULL,
    p_after_data jsonb DEFAULT NULL,
    p_reason varchar(500) DEFAULT NULL
)
RETURNS bigint
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = organisation, public
AS $$
DECLARE
    v_actor_str text;
    v_actor_id bigint;
    v_audit_action_id bigint;
    v_audit_id bigint;
    v_req_id uuid;
    v_ip inet;
    v_clean_before jsonb;
    v_clean_after jsonb;
BEGIN
    -- Actor validation: writes without actor fail with SQLSTATE 28000
    v_actor_str := nullif(current_setting('app.current_user_id', true), '');
    IF v_actor_str IS NULL THEN
        RAISE EXCEPTION 'Audit capture rejected: app.current_user_id session variable is not set'
            USING ERRCODE = '28000';
    END IF;
    v_actor_id := v_actor_str::bigint;

    SELECT id INTO v_audit_action_id
    FROM organisation.audit_action WHERE code = p_audit_action_code;

    IF v_audit_action_id IS NULL THEN
        RAISE EXCEPTION 'Unknown audit action code %', p_audit_action_code;
    END IF;

    BEGIN
        v_req_id := nullif(current_setting('app.request_id', true), '')::uuid;
    EXCEPTION WHEN OTHERS THEN
        v_req_id := NULL;
    END;

    BEGIN
        v_ip := nullif(current_setting('app.client_ip', true), '')::inet;
    EXCEPTION WHEN OTHERS THEN
        v_ip := NULL;
    END;

    -- Payload hygiene: strip sensitive keys
    v_clean_before := p_before_data - 'identifier_value_encrypted' - 'identifier_fingerprint' - 'verification_token_hash';
    v_clean_after := p_after_data - 'identifier_value_encrypted' - 'identifier_fingerprint' - 'verification_token_hash';

    INSERT INTO organisation.audit_event (
        audit_action_id, actor_id, entity_name, entity_id, organisation_id,
        is_success, request_id, ip_address, before_data, after_data, reason
    ) VALUES (
        v_audit_action_id, v_actor_id, p_entity_name, p_entity_id, p_organisation_id,
        p_is_success, v_req_id, v_ip, v_clean_before, v_clean_after,
        COALESCE(p_reason, nullif(current_setting('app.change_reason', true), ''))
    ) RETURNING id INTO v_audit_id;

    RETURN v_audit_id;
END;
$$;



-- ============================================================================
-- 5. HIGH-PERFORMANCE INDEXES (Section 6 & B34)
-- ============================================================================

CREATE INDEX idx_organisation_name ON organisation.organisation USING btree (lower(organisation_name));
CREATE INDEX idx_organisation_status ON organisation.organisation USING btree (organisation_status_id);
CREATE INDEX idx_account_administrator_user ON organisation.account_administrator USING btree (app_user_id);
CREATE INDEX idx_org_recruiter_user ON organisation.organisation_recruiter USING btree (app_user_id);
CREATE INDEX idx_org_relationship_parent ON organisation.organisation_relationship USING btree (parent_organisation_id);
CREATE INDEX idx_org_relationship_child ON organisation.organisation_relationship USING btree (child_organisation_id);
CREATE INDEX idx_org_audit_event_org_time ON organisation.audit_event USING btree (organisation_id, occurred_at DESC);
CREATE INDEX idx_org_audit_event_actor_time ON organisation.audit_event USING btree (actor_id, occurred_at DESC);


-- ============================================================================
-- 6. WIRE INTEGRATION FOREIGN KEY FROM ADMINISTRATION.ORGANISATION_BLOCK
-- ============================================================================
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint 
        WHERE conname = 'fk_organisation_block_org_id'
    ) THEN
        ALTER TABLE administration.organisation_block
            ADD CONSTRAINT fk_organisation_block_org_id
            FOREIGN KEY (organisation_id) REFERENCES organisation.organisation(id)
            ON UPDATE RESTRICT ON DELETE RESTRICT;
    END IF;
END;
$$;


-- ============================================================================
-- 7. ROLES, ROW-LEVEL SECURITY & ACCESS CONTROL (Section 6 & 8)
-- ============================================================================

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_catalog.pg_roles WHERE rolname = 'talentra_app') THEN
        CREATE ROLE talentra_app NOLOGIN;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_catalog.pg_roles WHERE rolname = 'talentra_auditor') THEN
        CREATE ROLE talentra_auditor NOLOGIN;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_catalog.pg_roles WHERE rolname = 'talentra_retention') THEN
        CREATE ROLE talentra_retention NOLOGIN;
    END IF;
END;
$$;

-- Enable Row-Level Security on Sensitive Organisation Identifiers
ALTER TABLE organisation.organisation_identifier ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS pol_organisation_identifier_admin ON organisation.organisation_identifier;
CREATE POLICY pol_organisation_identifier_admin ON organisation.organisation_identifier
FOR ALL
TO PUBLIC
USING (
    EXISTS (
        SELECT 1 FROM organisation.account a
        JOIN organisation.account_administrator aa ON aa.account_id = a.id
        WHERE a.organisation_id = organisation.organisation_identifier.organisation_id
          AND aa.app_user_id = nullif(current_setting('app.current_user_id', true), '')::bigint
          AND (aa.ended_at IS NULL OR aa.ended_at > CURRENT_TIMESTAMP)
    )
    OR
    EXISTS (
        SELECT 1 FROM administration.user_role ur
        JOIN administration.role r ON r.id = ur.role_id
        WHERE ur.user_account_id = nullif(current_setting('app.current_user_id', true), '')::bigint
          AND r.code IN ('super_admin', 'auditor')
    )
);

-- RLS Helper function used by Recruitment / Jobs module policies
CREATE OR REPLACE FUNCTION organisation.fn_current_user_is_assigned_recruiter(p_organisation_id bigint)
RETURNS boolean
LANGUAGE sql
STABLE
AS $$
    SELECT EXISTS (
        SELECT 1 FROM organisation.organisation_recruiter
        WHERE organisation_id = p_organisation_id
          AND app_user_id = nullif(current_setting('app.current_user_id', true), '')::bigint
          AND CURRENT_TIMESTAMP >= assignment_start_at
          AND (assignment_end_at IS NULL OR CURRENT_TIMESTAMP <= assignment_end_at)
    );
$$;


-- ============================================================================
-- 8. ACTIVE STATUS AND TENURE VIEWS (Section 1 & 13)
-- ============================================================================

CREATE OR REPLACE VIEW organisation.v_organisation_active AS
SELECT * FROM organisation.organisation WHERE deleted_at IS NULL;

CREATE OR REPLACE VIEW organisation.v_account_active AS
SELECT * FROM organisation.account WHERE deleted_at IS NULL;

CREATE OR REPLACE VIEW organisation.v_organisation_location_active AS
SELECT * FROM organisation.organisation_location WHERE deleted_at IS NULL;

CREATE OR REPLACE VIEW organisation.v_organisation_recruiter_active AS
SELECT * FROM organisation.organisation_recruiter
WHERE CURRENT_TIMESTAMP >= assignment_start_at
  AND (assignment_end_at IS NULL OR CURRENT_TIMESTAMP <= assignment_end_at);

