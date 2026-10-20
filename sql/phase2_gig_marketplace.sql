-- ============================================================================
-- Talentra: Job Search and Demand Management Platform
-- Database Schema Definition: Phase 2 Gig Marketplace Subsystem (v3)
-- Engine: PostgreSQL 14+
-- Conforming to: Talentra PRD Data Standards (Rule Groups 1 to 10)
-- Backlogs: B26 (Entities), B29 (Relationships), B32 (Columns), B35 (Keys & Constraints)
-- Target Schemas: master_data (service_category extension) & gig
-- ============================================================================

CREATE EXTENSION IF NOT EXISTS btree_gist;

-- ============================================================================
-- 1. MASTER DATA EXTENSION: SERVICE CATEGORY (Page 3 of Gig Spec)
-- ============================================================================
CREATE TABLE IF NOT EXISTS master_data.service_category (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    code varchar(50) NOT NULL,
    name varchar(100) NOT NULL,
    description text NULL,
    is_active boolean DEFAULT true NOT NULL,
    sort_order integer DEFAULT 0 NOT NULL,
    created_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_by bigint NULL,
    updated_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_by bigint NULL,
    CONSTRAINT uq_service_category_code UNIQUE (code),
    CONSTRAINT chk_service_category_code CHECK (code ~ '^[a-z][a-z0-9_]*$'),
    CONSTRAINT chk_service_category_sort_order CHECK (sort_order >= 0)
);

CREATE TRIGGER trg_service_category_updated_at BEFORE UPDATE ON master_data.service_category
FOR EACH ROW EXECUTE FUNCTION set_updated_at();


-- ============================================================================
-- 2. GIG MARKETPLACE SCHEMA & LOOKUP TABLES
-- ============================================================================
CREATE SCHEMA IF NOT EXISTS gig;

CREATE TABLE gig.lk_gig_availability_status (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    code varchar(30) NOT NULL,
    description text NULL,
    is_active boolean DEFAULT true NOT NULL,
    CONSTRAINT uq_lk_gig_availability_status_code UNIQUE (code)
);

CREATE TABLE gig.lk_gig_visibility_status (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    code varchar(30) NOT NULL,
    description text NULL,
    is_active boolean DEFAULT true NOT NULL,
    CONSTRAINT uq_lk_gig_visibility_status_code UNIQUE (code)
);

CREATE TABLE gig.lk_gig_work_mode (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    code varchar(20) NOT NULL,
    description text NULL,
    is_active boolean DEFAULT true NOT NULL,
    CONSTRAINT uq_lk_gig_work_mode_code UNIQUE (code)
);

CREATE TABLE gig.lk_gig_pricing_type (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    code varchar(20) NOT NULL,
    description text NULL,
    is_active boolean DEFAULT true NOT NULL,
    CONSTRAINT uq_lk_gig_pricing_type_code UNIQUE (code)
);

CREATE TABLE gig.lk_gig_rate_unit (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    code varchar(30) NOT NULL,
    description text NULL,
    is_active boolean DEFAULT true NOT NULL,
    CONSTRAINT uq_lk_gig_rate_unit_code UNIQUE (code)
);

CREATE TABLE gig.lk_gig_request_status (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    code varchar(30) NOT NULL,
    description text NULL,
    is_active boolean DEFAULT true NOT NULL,
    CONSTRAINT uq_lk_gig_request_status_code UNIQUE (code)
);

CREATE TABLE gig.lk_gig_application_status (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    code varchar(30) NOT NULL,
    description text NULL,
    is_active boolean DEFAULT true NOT NULL,
    CONSTRAINT uq_lk_gig_application_status_code UNIQUE (code)
);

CREATE TABLE gig.lk_gig_assignment_status (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    code varchar(30) NOT NULL,
    description text NULL,
    is_active boolean DEFAULT true NOT NULL,
    CONSTRAINT uq_lk_gig_assignment_status_code UNIQUE (code)
);

CREATE TABLE gig.lk_gig_proficiency_level (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    code varchar(30) NOT NULL,
    description text NULL,
    is_active boolean DEFAULT true NOT NULL,
    CONSTRAINT uq_lk_gig_proficiency_level_code UNIQUE (code)
);

CREATE TABLE gig.gig_status_transition (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    entity_type varchar(30) NOT NULL, -- 'request', 'application', 'assignment'
    from_status_code varchar(30) NOT NULL,
    to_status_code varchar(30) NOT NULL,
    created_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT uq_gig_status_transition UNIQUE (entity_type, from_status_code, to_status_code)
);


-- ============================================================================
-- 3. WORKER SIDE ENTITIES
-- ============================================================================

-- 3.1 Gig Worker Profile (Soft Delete)
CREATE TABLE gig.gig_worker_profile (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    app_user_id bigint NOT NULL,
    candidate_profile_id bigint NULL,
    professional_summary varchar(2000) NULL,
    portfolio_url varchar(2048) NULL,
    availability_status_code varchar(30) NOT NULL,
    visibility_status_code varchar(30) NOT NULL,
    content_language_code char(2) NULL,
    years_experience numeric(4,1) NULL,
    created_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_by bigint NOT NULL,
    updated_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_by bigint NOT NULL,
    deleted_at timestamptz NULL,
    deleted_by bigint NULL,
    CONSTRAINT fk_gig_worker_app_user FOREIGN KEY (app_user_id)
        REFERENCES administration.user_account(id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_gig_worker_candidate_profile FOREIGN KEY (candidate_profile_id)
        REFERENCES profile.candidate_profile(id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_gig_worker_avail_status FOREIGN KEY (availability_status_code)
        REFERENCES gig.lk_gig_availability_status(code) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_gig_worker_vis_status FOREIGN KEY (visibility_status_code)
        REFERENCES gig.lk_gig_visibility_status(code) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_gig_worker_created_by FOREIGN KEY (created_by)
        REFERENCES administration.user_account(id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_gig_worker_updated_by FOREIGN KEY (updated_by)
        REFERENCES administration.user_account(id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_gig_worker_deleted_by FOREIGN KEY (deleted_by)
        REFERENCES administration.user_account(id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT chk_gig_worker_years_exp CHECK (years_experience IS NULL OR years_experience >= 0),
    CONSTRAINT chk_gig_worker_soft_delete CHECK ((deleted_at IS NULL) = (deleted_by IS NULL))
);

CREATE UNIQUE INDEX uq_gig_worker_profile_app_user_id 
    ON gig.gig_worker_profile (app_user_id) 
    WHERE deleted_at IS NULL;

CREATE UNIQUE INDEX uq_gig_worker_profile_candidate_profile_id 
    ON gig.gig_worker_profile (candidate_profile_id) 
    WHERE candidate_profile_id IS NOT NULL AND deleted_at IS NULL;

-- 3.2 Gig Worker Service (Services Offered)
CREATE TABLE gig.gig_worker_service (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    gig_worker_profile_id bigint NOT NULL,
    service_category_id bigint NOT NULL,
    service_name varchar(150) NOT NULL,
    description varchar(2000) NULL,
    minimum_rate numeric(12,2) NULL,
    maximum_rate numeric(12,2) NULL,
    rate_unit_code varchar(30) NULL,
    currency_code char(3) NULL,
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_by bigint NOT NULL,
    updated_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_by bigint NOT NULL,
    deleted_at timestamptz NULL,
    deleted_by bigint NULL,
    CONSTRAINT fk_gig_service_worker FOREIGN KEY (gig_worker_profile_id)
        REFERENCES gig.gig_worker_profile(id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_gig_service_category FOREIGN KEY (service_category_id)
        REFERENCES master_data.service_category(id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_gig_service_rate_unit FOREIGN KEY (rate_unit_code)
        REFERENCES gig.lk_gig_rate_unit(code) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_gig_service_currency FOREIGN KEY (currency_code)
        REFERENCES master_data.currency(code) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_gig_service_created_by FOREIGN KEY (created_by)
        REFERENCES administration.user_account(id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_gig_service_updated_by FOREIGN KEY (updated_by)
        REFERENCES administration.user_account(id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_gig_service_deleted_by FOREIGN KEY (deleted_by)
        REFERENCES administration.user_account(id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT chk_gig_service_rates CHECK (
        (minimum_rate IS NULL OR minimum_rate > 0) AND
        (maximum_rate IS NULL OR maximum_rate > 0) AND
        (minimum_rate IS NULL OR maximum_rate IS NULL OR minimum_rate <= maximum_rate) AND
        ((minimum_rate IS NULL AND maximum_rate IS NULL) OR (currency_code IS NOT NULL AND rate_unit_code IS NOT NULL))
    ),
    CONSTRAINT chk_gig_service_soft_delete CHECK ((deleted_at IS NULL) = (deleted_by IS NULL))
);

CREATE UNIQUE INDEX uq_gig_worker_service_category_name 
    ON gig.gig_worker_service (gig_worker_profile_id, service_category_id, lower(service_name)) 
    WHERE deleted_at IS NULL;

-- 3.3 Gig Worker Skill (Hard Delete)
CREATE TABLE gig.gig_worker_skill (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    gig_worker_profile_id bigint NOT NULL,
    skill_id bigint NOT NULL,
    proficiency_level_code varchar(30) NULL,
    created_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_by bigint NOT NULL,
    CONSTRAINT fk_gig_worker_skill_worker FOREIGN KEY (gig_worker_profile_id)
        REFERENCES gig.gig_worker_profile(id) ON DELETE CASCADE,
    CONSTRAINT fk_gig_worker_skill_skill FOREIGN KEY (skill_id)
        REFERENCES master_data.skill(id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_gig_worker_skill_prof FOREIGN KEY (proficiency_level_code)
        REFERENCES gig.lk_gig_proficiency_level(code) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT uq_gig_worker_skill_pair UNIQUE (gig_worker_profile_id, skill_id)
);

-- 3.4 Gig Worker Availability (Non-overlapping calendar windows)
CREATE TABLE gig.gig_worker_availability (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    gig_worker_profile_id bigint NOT NULL,
    start_at timestamptz NOT NULL,
    end_at timestamptz NOT NULL,
    availability_status_code varchar(30) NOT NULL,
    source_timezone varchar(64) NULL,
    created_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_by bigint NOT NULL,
    updated_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_by bigint NOT NULL,
    deleted_at timestamptz NULL,
    deleted_by bigint NULL,
    CONSTRAINT fk_gig_avail_worker FOREIGN KEY (gig_worker_profile_id)
        REFERENCES gig.gig_worker_profile(id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_gig_avail_status FOREIGN KEY (availability_status_code)
        REFERENCES gig.lk_gig_availability_status(code) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_gig_avail_created_by FOREIGN KEY (created_by)
        REFERENCES administration.user_account(id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_gig_avail_updated_by FOREIGN KEY (updated_by)
        REFERENCES administration.user_account(id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_gig_avail_deleted_by FOREIGN KEY (deleted_by)
        REFERENCES administration.user_account(id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT chk_gig_avail_dates CHECK (end_at > start_at),
    CONSTRAINT chk_gig_avail_soft_delete CHECK ((deleted_at IS NULL) = (deleted_by IS NULL)),
    CONSTRAINT ex_gig_worker_availability_no_overlap EXCLUDE USING gist (
        gig_worker_profile_id WITH =,
        tstzrange(start_at, end_at) WITH &&
    ) WHERE (deleted_at IS NULL)
);


-- ============================================================================
-- 4. REQUEST SIDE ENTITIES
-- ============================================================================

-- 4.1 Gig Request (Job Demand on Gig Marketplace)
CREATE TABLE gig.gig_request (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    requester_user_id bigint NOT NULL,
    organisation_id bigint NULL,
    service_category_id bigint NOT NULL,
    title varchar(200) NOT NULL,
    description text NOT NULL,
    content_language_code char(2) NULL,
    work_mode_code varchar(20) NOT NULL,
    city_id bigint NULL,
    start_at timestamptz NOT NULL,
    end_at timestamptz NOT NULL,
    source_timezone varchar(64) NULL,
    positions_count smallint DEFAULT 1 NOT NULL,
    pricing_type_code varchar(20) NOT NULL,
    budget_amount numeric(12,2) NULL,
    rate_amount numeric(12,2) NULL,
    rate_unit_code varchar(30) NULL,
    currency_code char(3) NOT NULL,
    status_code varchar(30) NOT NULL,
    published_at timestamptz NULL,
    credit_ledger_entry_id bigint NULL,
    created_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_by bigint NOT NULL,
    updated_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_by bigint NOT NULL,
    deleted_at timestamptz NULL,
    deleted_by bigint NULL,
    CONSTRAINT fk_gig_req_requester FOREIGN KEY (requester_user_id)
        REFERENCES administration.user_account(id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_gig_req_org FOREIGN KEY (organisation_id)
        REFERENCES organisation.organisation(id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_gig_req_category FOREIGN KEY (service_category_id)
        REFERENCES master_data.service_category(id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_gig_req_work_mode FOREIGN KEY (work_mode_code)
        REFERENCES gig.lk_gig_work_mode(code) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_gig_req_city FOREIGN KEY (city_id)
        REFERENCES master_data.city(id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_gig_req_pricing_type FOREIGN KEY (pricing_type_code)
        REFERENCES gig.lk_gig_pricing_type(code) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_gig_req_rate_unit FOREIGN KEY (rate_unit_code)
        REFERENCES gig.lk_gig_rate_unit(code) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_gig_req_currency FOREIGN KEY (currency_code)
        REFERENCES master_data.currency(code) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_gig_req_status FOREIGN KEY (status_code)
        REFERENCES gig.lk_gig_request_status(code) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_gig_req_created_by FOREIGN KEY (created_by)
        REFERENCES administration.user_account(id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_gig_req_updated_by FOREIGN KEY (updated_by)
        REFERENCES administration.user_account(id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_gig_req_deleted_by FOREIGN KEY (deleted_by)
        REFERENCES administration.user_account(id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT chk_gig_req_dates CHECK (end_at > start_at),
    CONSTRAINT chk_gig_req_positions CHECK (positions_count >= 1),
    CONSTRAINT chk_gig_req_location CHECK (work_mode_code = 'remote' OR city_id IS NOT NULL),
    CONSTRAINT chk_gig_req_published CHECK (status_code <> 'published' OR published_at IS NOT NULL),
    CONSTRAINT chk_gig_req_pricing CHECK (
        (pricing_type_code = 'fixed_price' AND budget_amount > 0 AND rate_amount IS NULL AND rate_unit_code IS NULL) OR
        (pricing_type_code = 'rate_based' AND rate_amount > 0 AND rate_unit_code IS NOT NULL AND budget_amount IS NULL)
    ),
    CONSTRAINT chk_gig_req_soft_delete CHECK ((deleted_at IS NULL) = (deleted_by IS NULL))
);

-- 4.2 Gig Request Skill (Required skills)
CREATE TABLE gig.gig_request_skill (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    gig_request_id bigint NOT NULL,
    skill_id bigint NOT NULL,
    is_mandatory boolean DEFAULT true NOT NULL,
    created_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_by bigint NOT NULL,
    CONSTRAINT fk_gig_req_skill_req FOREIGN KEY (gig_request_id)
        REFERENCES gig.gig_request(id) ON DELETE CASCADE,
    CONSTRAINT fk_gig_req_skill_skill FOREIGN KEY (skill_id)
        REFERENCES master_data.skill(id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT uq_gig_request_skill_pair UNIQUE (gig_request_id, skill_id)
);

-- 4.3 Gig Request Status History (Append-only)
CREATE TABLE gig.gig_request_status_history (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    gig_request_id bigint NOT NULL,
    previous_status_code varchar(30) NULL,
    new_status_code varchar(30) NOT NULL,
    change_reason varchar(1000) NULL,
    created_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_by bigint NOT NULL,
    CONSTRAINT fk_gig_req_hist_req FOREIGN KEY (gig_request_id)
        REFERENCES gig.gig_request(id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_gig_req_hist_prev_status FOREIGN KEY (previous_status_code)
        REFERENCES gig.lk_gig_request_status(code) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_gig_req_hist_new_status FOREIGN KEY (new_status_code)
        REFERENCES gig.lk_gig_request_status(code) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_gig_req_hist_created_by FOREIGN KEY (created_by)
        REFERENCES administration.user_account(id) ON UPDATE RESTRICT ON DELETE RESTRICT
);


-- ============================================================================
-- 5. APPLICATION & ASSIGNMENT ENTITIES
-- ============================================================================

-- 5.1 Gig Application (Worker proposals)
CREATE TABLE gig.gig_application (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    gig_request_id bigint NOT NULL,
    gig_worker_profile_id bigint NOT NULL,
    proposed_amount numeric(12,2) NULL,
    currency_code char(3) NULL,
    rate_unit_code varchar(30) NULL,
    proposal_text varchar(4000) NULL,
    status_code varchar(30) NOT NULL,
    applied_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    decided_by_user_id bigint NULL,
    decided_at timestamptz NULL,
    decision_note varchar(1000) NULL,
    created_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_by bigint NOT NULL,
    updated_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_by bigint NOT NULL,
    deleted_at timestamptz NULL,
    deleted_by bigint NULL,
    CONSTRAINT fk_gig_app_req FOREIGN KEY (gig_request_id)
        REFERENCES gig.gig_request(id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_gig_app_worker FOREIGN KEY (gig_worker_profile_id)
        REFERENCES gig.gig_worker_profile(id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_gig_app_currency FOREIGN KEY (currency_code)
        REFERENCES master_data.currency(code) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_gig_app_rate_unit FOREIGN KEY (rate_unit_code)
        REFERENCES gig.lk_gig_rate_unit(code) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_gig_app_status FOREIGN KEY (status_code)
        REFERENCES gig.lk_gig_application_status(code) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_gig_app_decided_by FOREIGN KEY (decided_by_user_id)
        REFERENCES administration.user_account(id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_gig_app_created_by FOREIGN KEY (created_by)
        REFERENCES administration.user_account(id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_gig_app_updated_by FOREIGN KEY (updated_by)
        REFERENCES administration.user_account(id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_gig_app_deleted_by FOREIGN KEY (deleted_by)
        REFERENCES administration.user_account(id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT uq_gig_application_composite UNIQUE (id, gig_request_id, gig_worker_profile_id),
    CONSTRAINT chk_gig_app_proposal CHECK (
        (proposed_amount IS NULL AND currency_code IS NULL) OR
        (proposed_amount > 0 AND currency_code IS NOT NULL)
    ),
    CONSTRAINT chk_gig_app_decision CHECK (
        (status_code IN ('accepted', 'rejected') AND decided_at IS NOT NULL AND decided_by_user_id IS NOT NULL) OR
        (status_code NOT IN ('accepted', 'rejected'))
    ),
    CONSTRAINT chk_gig_app_soft_delete CHECK ((deleted_at IS NULL) = (deleted_by IS NULL))
);

CREATE UNIQUE INDEX uq_gig_application_request_worker 
    ON gig.gig_application (gig_request_id, gig_worker_profile_id) 
    WHERE status_code <> 'withdrawn' AND deleted_at IS NULL;

-- 5.2 Gig Application Status History (Append-only)
CREATE TABLE gig.gig_application_status_history (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    gig_application_id bigint NOT NULL,
    previous_status_code varchar(30) NULL,
    new_status_code varchar(30) NOT NULL,
    change_reason varchar(1000) NULL,
    created_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_by bigint NOT NULL,
    CONSTRAINT fk_gig_app_hist_app FOREIGN KEY (gig_application_id)
        REFERENCES gig.gig_application(id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_gig_app_hist_prev_status FOREIGN KEY (previous_status_code)
        REFERENCES gig.lk_gig_application_status(code) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_gig_app_hist_new_status FOREIGN KEY (new_status_code)
        REFERENCES gig.lk_gig_application_status(code) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_gig_app_hist_created_by FOREIGN KEY (created_by)
        REFERENCES administration.user_account(id) ON UPDATE RESTRICT ON DELETE RESTRICT
);

-- 5.3 Gig Assignment (Executed contract from accepted application)
CREATE TABLE gig.gig_assignment (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    gig_request_id bigint NOT NULL,
    gig_application_id bigint NOT NULL,
    gig_worker_profile_id bigint NOT NULL,
    profile_project_id bigint NULL,
    pricing_type_code varchar(20) NOT NULL,
    agreed_amount numeric(12,2) NOT NULL,
    rate_unit_code varchar(30) NULL,
    currency_code char(3) NOT NULL,
    status_code varchar(30) NOT NULL,
    assigned_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    started_at timestamptz NULL,
    completed_at timestamptz NULL,
    created_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_by bigint NOT NULL,
    updated_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_by bigint NOT NULL,
    deleted_at timestamptz NULL,
    deleted_by bigint NULL,
    CONSTRAINT fk_gig_assign_req FOREIGN KEY (gig_request_id)
        REFERENCES gig.gig_request(id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_gig_assign_app_composite FOREIGN KEY (gig_application_id, gig_request_id, gig_worker_profile_id)
        REFERENCES gig.gig_application(id, gig_request_id, gig_worker_profile_id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_gig_assign_worker FOREIGN KEY (gig_worker_profile_id)
        REFERENCES gig.gig_worker_profile(id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_gig_assign_project FOREIGN KEY (profile_project_id)
        REFERENCES profile.profile_project(id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_gig_assign_pricing_type FOREIGN KEY (pricing_type_code)
        REFERENCES gig.lk_gig_pricing_type(code) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_gig_assign_rate_unit FOREIGN KEY (rate_unit_code)
        REFERENCES gig.lk_gig_rate_unit(code) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_gig_assign_currency FOREIGN KEY (currency_code)
        REFERENCES master_data.currency(code) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_gig_assign_status FOREIGN KEY (status_code)
        REFERENCES gig.lk_gig_assignment_status(code) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_gig_assign_created_by FOREIGN KEY (created_by)
        REFERENCES administration.user_account(id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_gig_assign_updated_by FOREIGN KEY (updated_by)
        REFERENCES administration.user_account(id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_gig_assign_deleted_by FOREIGN KEY (deleted_by)
        REFERENCES administration.user_account(id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT chk_gig_assign_amount CHECK (agreed_amount > 0),
    CONSTRAINT chk_gig_assign_soft_delete CHECK ((deleted_at IS NULL) = (deleted_by IS NULL))
);

-- 5.4 Gig Assignment Status History (Append-only)
CREATE TABLE gig.gig_assignment_status_history (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    gig_assignment_id bigint NOT NULL,
    previous_status_code varchar(30) NULL,
    new_status_code varchar(30) NOT NULL,
    change_reason varchar(1000) NULL,
    created_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_by bigint NOT NULL,
    CONSTRAINT fk_gig_assign_hist_assign FOREIGN KEY (gig_assignment_id)
        REFERENCES gig.gig_assignment(id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_gig_assign_hist_prev_status FOREIGN KEY (previous_status_code)
        REFERENCES gig.lk_gig_assignment_status(code) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_gig_assign_hist_new_status FOREIGN KEY (new_status_code)
        REFERENCES gig.lk_gig_assignment_status(code) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_gig_assign_hist_created_by FOREIGN KEY (created_by)
        REFERENCES administration.user_account(id) ON UPDATE RESTRICT ON DELETE RESTRICT
);


-- ============================================================================
-- 6. INTEGRATION, FEEDBACK & RATING ENTITIES
-- ============================================================================

-- 6.1 Gig Fulfilment Reference (External delivery systems)
CREATE TABLE gig.gig_fulfilment_reference (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    gig_assignment_id bigint NOT NULL,
    external_system_code varchar(50) NOT NULL,
    external_reference varchar(255) NOT NULL,
    sync_status_code varchar(30) NOT NULL DEFAULT 'synced',
    created_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_by bigint NOT NULL,
    updated_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_by bigint NOT NULL,
    CONSTRAINT fk_gig_fulfil_assign FOREIGN KEY (gig_assignment_id)
        REFERENCES gig.gig_assignment(id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT uq_gig_fulfil_external UNIQUE (external_system_code, external_reference)
);

-- 6.2 Gig Fulfilment Event (Append-only events)
CREATE TABLE gig.gig_fulfilment_event (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    gig_fulfilment_reference_id bigint NOT NULL,
    event_type_code varchar(50) NOT NULL,
    event_payload jsonb NOT NULL DEFAULT '{}'::jsonb,
    duplicate_count integer DEFAULT 0 NOT NULL CHECK (duplicate_count >= 0),
    created_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_by bigint NOT NULL,
    CONSTRAINT fk_gig_fulfil_event_ref FOREIGN KEY (gig_fulfilment_reference_id)
        REFERENCES gig.gig_fulfilment_reference(id) ON UPDATE RESTRICT ON DELETE RESTRICT
);

-- 6.3 Gig Earnings Reference
CREATE TABLE gig.gig_earnings_reference (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    gig_assignment_id bigint NOT NULL,
    latest_amount numeric(12,2) NOT NULL DEFAULT 0.00 CHECK (latest_amount >= 0),
    currency_code char(3) NOT NULL,
    created_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_by bigint NOT NULL,
    updated_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_by bigint NOT NULL,
    CONSTRAINT fk_gig_earnings_assign FOREIGN KEY (gig_assignment_id)
        REFERENCES gig.gig_assignment(id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_gig_earnings_currency FOREIGN KEY (currency_code)
        REFERENCES master_data.currency(code) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT uq_gig_earnings_assignment UNIQUE (gig_assignment_id)
);

-- 6.4 Gig Earnings History (Append-only)
CREATE TABLE gig.gig_earnings_history (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    gig_earnings_reference_id bigint NOT NULL,
    amount numeric(12,2) NOT NULL CHECK (amount >= 0),
    change_type_code varchar(40) NOT NULL, -- 'milestone_payout', 'adjustment', 'correction'
    reason varchar(500) NULL,
    created_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_by bigint NOT NULL,
    CONSTRAINT fk_gig_earnings_hist_ref FOREIGN KEY (gig_earnings_reference_id)
        REFERENCES gig.gig_earnings_reference(id) ON UPDATE RESTRICT ON DELETE RESTRICT
);

-- 6.5 Gig Worker List Entry (Requester bookmarks & worker shortlists)
CREATE TABLE gig.gig_worker_list_entry (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    app_user_id bigint NOT NULL,
    gig_worker_profile_id bigint NOT NULL,
    list_name varchar(100) NOT NULL DEFAULT 'favorites',
    notes varchar(1000) NULL,
    created_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_by bigint NOT NULL,
    CONSTRAINT fk_gig_list_user FOREIGN KEY (app_user_id)
        REFERENCES administration.user_account(id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_gig_list_worker FOREIGN KEY (gig_worker_profile_id)
        REFERENCES gig.gig_worker_profile(id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT uq_gig_worker_list_pair UNIQUE (app_user_id, gig_worker_profile_id, list_name)
);

-- 6.6 Gig Rating (Feedback on completed assignment)
CREATE TABLE gig.gig_rating (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    gig_assignment_id bigint NOT NULL,
    rater_user_id bigint NOT NULL,
    rated_user_id bigint NOT NULL,
    rating_score smallint NOT NULL CHECK (rating_score BETWEEN 1 AND 5),
    feedback_text varchar(2000) NULL,
    created_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_by bigint NOT NULL,
    CONSTRAINT fk_gig_rating_assign FOREIGN KEY (gig_assignment_id)
        REFERENCES gig.gig_assignment(id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_gig_rating_rater FOREIGN KEY (rater_user_id)
        REFERENCES administration.user_account(id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_gig_rating_rated FOREIGN KEY (rated_user_id)
        REFERENCES administration.user_account(id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT uq_gig_rating_assignment_rater UNIQUE (gig_assignment_id, rater_user_id),
    CONSTRAINT chk_gig_rating_distinct CHECK (rater_user_id <> rated_user_id)
);


-- ============================================================================
-- 7. AUTOMATED TRIGGERS & BUSINESS INTEGRITY GUARDS
-- ============================================================================

-- updated_at triggers
CREATE TRIGGER trg_gig_worker_profile_updated_at BEFORE UPDATE ON gig.gig_worker_profile
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_gig_worker_service_updated_at BEFORE UPDATE ON gig.gig_worker_service
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_gig_worker_avail_updated_at BEFORE UPDATE ON gig.gig_worker_availability
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_gig_request_updated_at BEFORE UPDATE ON gig.gig_request
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_gig_application_updated_at BEFORE UPDATE ON gig.gig_application
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_gig_assignment_updated_at BEFORE UPDATE ON gig.gig_assignment
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_gig_fulfilment_ref_updated_at BEFORE UPDATE ON gig.gig_fulfilment_reference
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_gig_earnings_ref_updated_at BEFORE UPDATE ON gig.gig_earnings_reference
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- Append-only enforcement on history and event tables
CREATE TRIGGER trg_gig_req_hist_append_only BEFORE UPDATE OR DELETE ON gig.gig_request_status_history
FOR EACH ROW EXECUTE FUNCTION enforce_append_only();

CREATE TRIGGER trg_gig_app_hist_append_only BEFORE UPDATE OR DELETE ON gig.gig_application_status_history
FOR EACH ROW EXECUTE FUNCTION enforce_append_only();

CREATE TRIGGER trg_gig_assign_hist_append_only BEFORE UPDATE OR DELETE ON gig.gig_assignment_status_history
FOR EACH ROW EXECUTE FUNCTION enforce_append_only();

CREATE TRIGGER trg_gig_fulfil_event_append_only BEFORE UPDATE OR DELETE ON gig.gig_fulfilment_event
FOR EACH ROW EXECUTE FUNCTION enforce_append_only();

CREATE TRIGGER trg_gig_earnings_hist_append_only BEFORE UPDATE OR DELETE ON gig.gig_earnings_history
FOR EACH ROW EXECUTE FUNCTION enforce_append_only();

-- Self-application prevention trigger
CREATE OR REPLACE FUNCTION gig.prevent_self_application()
RETURNS TRIGGER AS $$
DECLARE
    v_requester_user_id bigint;
    v_worker_user_id bigint;
    v_request_status varchar(30);
BEGIN
    SELECT requester_user_id, status_code INTO v_requester_user_id, v_request_status
    FROM gig.gig_request WHERE id = NEW.gig_request_id;

    SELECT app_user_id INTO v_worker_user_id
    FROM gig.gig_worker_profile WHERE id = NEW.gig_worker_profile_id;

    IF (v_requester_user_id = v_worker_user_id) THEN
        RAISE EXCEPTION 'Self-application forbidden: worker owns the gig request'
            USING ERRCODE = '23514';
    END IF;

    IF (v_request_status <> 'published') THEN
        RAISE EXCEPTION 'Cannot apply to gig request with status % (must be published)', v_request_status
            USING ERRCODE = '23514';
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_prevent_self_application
BEFORE INSERT ON gig.gig_application
FOR EACH ROW EXECUTE FUNCTION gig.prevent_self_application();

-- Positions cap enforcement trigger
CREATE OR REPLACE FUNCTION gig.enforce_positions_cap()
RETURNS TRIGGER AS $$
DECLARE
    v_max_positions smallint;
    v_current_active integer;
BEGIN
    SELECT positions_count INTO v_max_positions
    FROM gig.gig_request WHERE id = NEW.gig_request_id;

    SELECT count(*) INTO v_current_active
    FROM gig.gig_assignment
    WHERE gig_request_id = NEW.gig_request_id
      AND status_code IN ('pending_handoff', 'active', 'completed')
      AND id <> COALESCE(NEW.id, -1);

    IF (v_current_active >= v_max_positions) THEN
        RAISE EXCEPTION 'Positions cap reached for gig request % (limit: %)',
            NEW.gig_request_id, v_max_positions
            USING ERRCODE = '23514';
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_enforce_positions_cap
BEFORE INSERT ON gig.gig_assignment
FOR EACH ROW EXECUTE FUNCTION gig.enforce_positions_cap();


-- ============================================================================
-- 8. HIGH-PERFORMANCE INDEXES (Section 6 & B35)
-- ============================================================================

CREATE INDEX idx_gig_worker_skill_skill ON gig.gig_worker_skill USING btree (skill_id);
CREATE INDEX idx_gig_request_status_start ON gig.gig_request USING btree (status_code, start_at);
CREATE INDEX idx_gig_request_category ON gig.gig_request USING btree (service_category_id);
CREATE INDEX idx_gig_request_city ON gig.gig_request USING btree (city_id);
CREATE INDEX idx_gig_request_org ON gig.gig_request USING btree (organisation_id);
CREATE INDEX idx_gig_request_skill_skill ON gig.gig_request_skill USING btree (skill_id);
CREATE INDEX idx_gig_app_request_status ON gig.gig_application USING btree (gig_request_id, status_code);
CREATE INDEX idx_gig_app_worker ON gig.gig_application USING btree (gig_worker_profile_id);
CREATE INDEX idx_gig_assign_worker ON gig.gig_assignment USING btree (gig_worker_profile_id);
CREATE INDEX idx_gig_assign_status ON gig.gig_assignment USING btree (status_code);


-- ============================================================================
-- 9. ACTIVE MARKETPLACE VIEWS (Fix 11: v_gig_ prefix)
-- ============================================================================

CREATE OR REPLACE VIEW gig.v_gig_request_published AS
SELECT * FROM gig.gig_request
WHERE status_code = 'published' AND deleted_at IS NULL;

CREATE OR REPLACE VIEW gig.v_gig_worker_available AS
SELECT * FROM gig.gig_worker_profile
WHERE availability_status_code = 'accepting_work' AND deleted_at IS NULL;

CREATE OR REPLACE VIEW gig.v_gig_assignment_active AS
SELECT * FROM gig.gig_assignment
WHERE status_code IN ('pending_handoff', 'active');

