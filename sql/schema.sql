-- ============================================================================
-- Talentra: Job Search and Demand Management Platform
-- Database Schema Definition (Phase 1 Foundation: Master Data, Profile, Recruitment)
-- Engine: PostgreSQL 14+
-- Conforming to: Talentra PRD Data Standards and Domain Rules (Rule Groups 1 to 10)
-- Extended with: Phase 1 Foundation Proposed Design Pack (B1–B23 Complete)
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
-- EXTENSIONS & SCHEMAS (Domain-driven partitioning per Rule Group 8)
-- ----------------------------------------------------------------------------
CREATE EXTENSION IF NOT EXISTS pg_trgm;

CREATE SCHEMA IF NOT EXISTS master_data;
CREATE SCHEMA IF NOT EXISTS profile;
CREATE SCHEMA IF NOT EXISTS recruitment;

-- ----------------------------------------------------------------------------
-- HELPER FUNCTIONS FOR AUDIT INTEGRITY (Rule Group 4 & 10)
-- ----------------------------------------------------------------------------

-- Automatically updates updated_at timestamp on record modification
CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Strictly forbids UPDATE and DELETE operations on append-only historical ledgers
CREATE OR REPLACE FUNCTION enforce_append_only()
RETURNS TRIGGER AS $$
BEGIN
    RAISE EXCEPTION 'Table % is strictly append-only. UPDATE and DELETE operations are prohibited.', TG_TABLE_NAME;
END;
$$ LANGUAGE plpgsql;


-- ============================================================================
-- MODULE 1: MASTER DATA
-- Global reference entities, geography, lookups, and multilingual UI strings.
-- ============================================================================

-- Countries (ISO 3166-1 alpha-2, alpha-3, and E.164 phone prefixes)
CREATE TABLE master_data.country (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    iso_code_2 char(2) NOT NULL,
    iso_code_3 char(3) NOT NULL,
    name varchar(100) NOT NULL,
    phone_code varchar(10) NOT NULL,
    is_active boolean NOT NULL DEFAULT true,
    created_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_by bigint NULL,
    updated_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_by bigint NULL,
    CONSTRAINT uq_country_iso_code_2 UNIQUE (iso_code_2),
    CONSTRAINT uq_country_iso_code_3 UNIQUE (iso_code_3),
    CONSTRAINT uq_country_name UNIQUE (name)
);

-- States / Provinces
CREATE TABLE master_data.state (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    country_id bigint NOT NULL,
    name varchar(100) NOT NULL,
    code varchar(20) NOT NULL,
    is_active boolean NOT NULL DEFAULT true,
    created_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_by bigint NULL,
    updated_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_by bigint NULL,
    CONSTRAINT fk_state_country_id FOREIGN KEY (country_id)
        REFERENCES master_data.country(id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT uq_state_country_id_code UNIQUE (country_id, code)
);

-- Cities (Direct country link, optional state for unitary states, coordinates per Rule Group 3)
CREATE TABLE master_data.city (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    country_id bigint NOT NULL,
    state_id bigint NULL,
    name varchar(100) NOT NULL,
    postal_code varchar(20) NULL,
    latitude numeric(9,6) NULL,
    longitude numeric(9,6) NULL,
    is_active boolean NOT NULL DEFAULT true,
    created_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_by bigint NULL,
    updated_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_by bigint NULL,
    CONSTRAINT fk_city_country_id FOREIGN KEY (country_id)
        REFERENCES master_data.country(id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_city_state_id FOREIGN KEY (state_id)
        REFERENCES master_data.state(id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT chk_city_latitude CHECK (latitude IS NULL OR (latitude >= -90.0 AND latitude <= 90.0)),
    CONSTRAINT chk_city_longitude CHECK (longitude IS NULL OR (longitude >= -180.0 AND longitude <= 180.0))
);

-- Locations (Specific office park, campus, or sub-locality granularity)
CREATE TABLE master_data.location (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    country_id bigint NOT NULL,
    city_id bigint NULL,
    location_name varchar(150) NOT NULL,
    latitude numeric(9,6) NULL,
    longitude numeric(9,6) NULL,
    is_active boolean NOT NULL DEFAULT true,
    created_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_by bigint NULL,
    updated_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_by bigint NULL,
    CONSTRAINT fk_location_country_id FOREIGN KEY (country_id)
        REFERENCES master_data.country(id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_location_city_id FOREIGN KEY (city_id)
        REFERENCES master_data.city(id) ON UPDATE RESTRICT ON DELETE RESTRICT
);

-- Currencies (Companion lookup for monetary amounts, ISO 4217 per Rule Group 3)
CREATE TABLE master_data.currency (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    code char(3) NOT NULL,
    name varchar(50) NOT NULL,
    symbol varchar(10) NOT NULL,
    is_active boolean NOT NULL DEFAULT true,
    created_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_by bigint NULL,
    updated_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_by bigint NULL,
    CONSTRAINT uq_currency_code UNIQUE (code)
);

-- Languages (ISO 639-1 / UTF-8 catalog)
CREATE TABLE master_data.language (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    code varchar(10) NOT NULL,
    name varchar(100) NOT NULL,
    is_active boolean NOT NULL DEFAULT true,
    created_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_by bigint NULL,
    updated_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_by bigint NULL,
    CONSTRAINT uq_language_code UNIQUE (code),
    CONSTRAINT uq_language_name UNIQUE (name)
);

-- UI Translation Keys (Rule Group 7: UI strings stored by key)
CREATE TABLE master_data.ui_translation_key (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    key_code varchar(150) NOT NULL,
    default_text text NOT NULL,
    description varchar(255) NULL,
    created_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_by bigint NULL,
    updated_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_by bigint NULL,
    CONSTRAINT uq_ui_translation_key_key_code UNIQUE (key_code)
);

-- UI Translations (One row per key and language, fallback supported per Rule Group 7)
CREATE TABLE master_data.ui_translation (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    ui_translation_key_id bigint NOT NULL,
    language_id bigint NOT NULL,
    translation text NOT NULL,
    is_fallback boolean NOT NULL DEFAULT false,
    created_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_by bigint NULL,
    updated_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_by bigint NULL,
    CONSTRAINT fk_ui_translation_key_id FOREIGN KEY (ui_translation_key_id)
        REFERENCES master_data.ui_translation_key(id) ON UPDATE RESTRICT ON DELETE CASCADE,
    CONSTRAINT fk_ui_translation_language_id FOREIGN KEY (language_id)
        REFERENCES master_data.language(id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT uq_ui_translation_key_language UNIQUE (ui_translation_key_id, language_id)
);

-- Education Levels / Tiers
CREATE TABLE master_data.education_level (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    level_name varchar(100) NOT NULL,
    sort_order integer NOT NULL DEFAULT 0,
    is_active boolean NOT NULL DEFAULT true,
    created_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_by bigint NULL,
    updated_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_by bigint NULL,
    CONSTRAINT uq_education_level_level_name UNIQUE (level_name)
);

-- Qualifications (Specific degree titles mapped to education level, e.g., B.Tech, M.S., B.Sc.)
CREATE TABLE master_data.qualification (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    education_level_id bigint NULL,
    qualification_name varchar(150) NOT NULL,
    qualification_code varchar(40) NULL,
    is_active boolean NOT NULL DEFAULT true,
    created_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_by bigint NULL,
    updated_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_by bigint NULL,
    CONSTRAINT fk_qualification_education_level_id FOREIGN KEY (education_level_id)
        REFERENCES master_data.education_level(id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT uq_qualification_name UNIQUE (qualification_name)
);

-- Employment Types (Full-time, Part-time, Contract, Apprentice, etc.)
CREATE TABLE master_data.employment_type (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    type_name varchar(50) NOT NULL,
    is_active boolean NOT NULL DEFAULT true,
    created_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_by bigint NULL,
    updated_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_by bigint NULL,
    CONSTRAINT uq_employment_type_type_name UNIQUE (type_name)
);

-- Work Types (On-site, Hybrid, Remote)
CREATE TABLE master_data.work_type (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    type_name varchar(50) NOT NULL,
    is_active boolean NOT NULL DEFAULT true,
    created_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_by bigint NULL,
    updated_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_by bigint NULL,
    CONSTRAINT uq_work_type_type_name UNIQUE (type_name)
);

-- Industries
CREATE TABLE master_data.industry (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    industry_name varchar(150) NOT NULL,
    industry_code varchar(40) NULL,
    is_active boolean NOT NULL DEFAULT true,
    created_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_by bigint NULL,
    updated_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_by bigint NULL,
    CONSTRAINT uq_industry_industry_name UNIQUE (industry_name)
);

-- Job Roles
CREATE TABLE master_data.job_role (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    industry_id bigint NOT NULL,
    role_name varchar(150) NOT NULL,
    role_code varchar(40) NULL,
    is_active boolean NOT NULL DEFAULT true,
    created_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_by bigint NULL,
    updated_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_by bigint NULL,
    CONSTRAINT fk_job_role_industry_id FOREIGN KEY (industry_id)
        REFERENCES master_data.industry(id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT uq_job_role_industry_role UNIQUE (industry_id, role_name)
);

-- Skills (With normalized_name for case-insensitive and synonym matching)
CREATE TABLE master_data.skill (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    skill_name varchar(100) NOT NULL,
    normalized_name varchar(150) NULL,
    is_active boolean NOT NULL DEFAULT true,
    created_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_by bigint NULL,
    updated_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_by bigint NULL,
    CONSTRAINT uq_skill_skill_name UNIQUE (skill_name)
);

-- Proficiency Levels (Rule Group 3: Structured lookup instead of free-text enum)
CREATE TABLE master_data.proficiency_level (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    code varchar(30) NOT NULL,
    display_name varchar(50) NOT NULL,
    sort_order integer NOT NULL DEFAULT 0,
    is_active boolean NOT NULL DEFAULT true,
    created_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_by bigint NULL,
    updated_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_by bigint NULL,
    CONSTRAINT uq_proficiency_level_code UNIQUE (code)
);

-- Job Requirement Status Lookup
CREATE TABLE master_data.job_requirement_status (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    code varchar(30) NOT NULL,
    display_name varchar(50) NOT NULL,
    sort_order integer NOT NULL DEFAULT 0,
    is_active boolean NOT NULL DEFAULT true,
    created_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_by bigint NULL,
    updated_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_by bigint NULL,
    CONSTRAINT uq_job_requirement_status_code UNIQUE (code)
);

-- Application Status Lookup (Pipeline stages: submitted, screening, shortlisted, interview, offered, joined, rejected, withdrawn)
CREATE TABLE master_data.application_status (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    code varchar(30) NOT NULL,
    display_name varchar(50) NOT NULL,
    sort_order integer NOT NULL DEFAULT 0,
    is_active boolean NOT NULL DEFAULT true,
    created_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_by bigint NULL,
    updated_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_by bigint NULL,
    CONSTRAINT uq_application_status_code UNIQUE (code)
);

-- Interview Status Lookup
CREATE TABLE master_data.interview_status (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    code varchar(30) NOT NULL,
    display_name varchar(50) NOT NULL,
    sort_order integer NOT NULL DEFAULT 0,
    is_active boolean NOT NULL DEFAULT true,
    created_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_by bigint NULL,
    updated_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_by bigint NULL,
    CONSTRAINT uq_interview_status_code UNIQUE (code)
);

-- Interview Type Lookup (Technical, HR, Managerial, Panel)
CREATE TABLE master_data.interview_type (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    code varchar(30) NOT NULL,
    display_name varchar(50) NOT NULL,
    sort_order integer NOT NULL DEFAULT 0,
    is_active boolean NOT NULL DEFAULT true,
    created_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_by bigint NULL,
    updated_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_by bigint NULL,
    CONSTRAINT uq_interview_type_code UNIQUE (code)
);

-- Offer Status Lookup (Pending, Accepted, Declined, Revoked)
CREATE TABLE master_data.offer_status (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    code varchar(30) NOT NULL,
    display_name varchar(50) NOT NULL,
    sort_order integer NOT NULL DEFAULT 0,
    is_active boolean NOT NULL DEFAULT true,
    created_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_by bigint NULL,
    updated_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_by bigint NULL,
    CONSTRAINT uq_offer_status_code UNIQUE (code)
);

-- Question Type Lookup (Text, Single Choice, Multiple Choice, Boolean)
CREATE TABLE master_data.question_type (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    code varchar(30) NOT NULL,
    display_name varchar(50) NOT NULL,
    sort_order integer NOT NULL DEFAULT 0,
    is_active boolean NOT NULL DEFAULT true,
    created_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_by bigint NULL,
    updated_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_by bigint NULL,
    CONSTRAINT uq_question_type_code UNIQUE (code)
);

-- Referral Status Lookup (For referral tracking workflow)
CREATE TABLE master_data.referral_status (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    code varchar(30) NOT NULL,
    display_name varchar(50) NOT NULL,
    sort_order integer NOT NULL DEFAULT 0,
    is_active boolean NOT NULL DEFAULT true,
    created_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_by bigint NULL,
    updated_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_by bigint NULL,
    CONSTRAINT uq_referral_status_code UNIQUE (code)
);


-- ============================================================================
-- MODULE 2: PROFILE
-- Candidate core profile, contact, education, work experience, skills,
-- languages, resumes, templates, projects, assessments, certifications, preferences, and awards.
-- ============================================================================

-- Candidate Profile Core
-- Rule 3: Person name text up to 150 chars, UTF-8, script/order neutral.
-- Rule 4: Standard audit columns + deleted_at for soft deletion.
-- Rule 7: User-entered content language recorded where known.
-- Linkage: user_id for shared identity linkage, visibility code for privacy.
CREATE TABLE profile.candidate_profile (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user_id bigint NULL, -- Cross-module reference to shared auth/account module
    full_name varchar(150) NOT NULL,
    date_of_birth date NULL,
    headline varchar(250) NULL,
    summary varchar(2000) NULL,
    country_id bigint NULL,
    city_id bigint NULL,
    years_experience numeric(4,1) NULL,
    profile_completion_percentage numeric(5,2) NOT NULL DEFAULT 0.00,
    profile_visibility_code varchar(30) NOT NULL DEFAULT 'public',
    content_language_id bigint NULL,
    created_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_by bigint NULL,
    updated_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_by bigint NULL,
    deleted_at timestamptz NULL,
    CONSTRAINT chk_candidate_profile_years_experience CHECK (years_experience IS NULL OR years_experience >= 0.0),
    CONSTRAINT chk_candidate_profile_completion CHECK (profile_completion_percentage >= 0.00 AND profile_completion_percentage <= 100.00),
    CONSTRAINT fk_candidate_profile_country_id FOREIGN KEY (country_id)
        REFERENCES master_data.country(id) ON UPDATE RESTRICT ON DELETE SET NULL,
    CONSTRAINT fk_candidate_profile_city_id FOREIGN KEY (city_id)
        REFERENCES master_data.city(id) ON UPDATE RESTRICT ON DELETE SET NULL,
    CONSTRAINT fk_candidate_profile_language_id FOREIGN KEY (content_language_id)
        REFERENCES master_data.language(id) ON UPDATE RESTRICT ON DELETE SET NULL
);

-- Partial unique index for active candidates (prevents lockout on soft-deleted re-registration)
CREATE UNIQUE INDEX uq_candidate_profile_active_user ON profile.candidate_profile (user_id) WHERE deleted_at IS NULL;

-- Candidate Contact Details
-- Rule 3: Email up to 254 chars, lowercase unique. Phone in E.164 with country code.
CREATE TABLE profile.candidate_contact (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    candidate_profile_id bigint NOT NULL,
    email varchar(254) NOT NULL,
    phone varchar(30) NULL,
    phone_country_code varchar(10) NULL,
    city_id bigint NULL,
    country_id bigint NULL,
    address_line varchar(255) NULL,
    postal_code varchar(20) NULL,
    contact_visibility_code varchar(30) NOT NULL DEFAULT 'recruiter_only',
    created_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_by bigint NULL,
    updated_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_by bigint NULL,
    deleted_at timestamptz NULL,
    CONSTRAINT fk_candidate_contact_candidate_profile_id FOREIGN KEY (candidate_profile_id)
        REFERENCES profile.candidate_profile(id) ON UPDATE RESTRICT ON DELETE CASCADE,
    CONSTRAINT fk_candidate_contact_city_id FOREIGN KEY (city_id)
        REFERENCES master_data.city(id) ON UPDATE RESTRICT ON DELETE SET NULL,
    CONSTRAINT fk_candidate_contact_country_id FOREIGN KEY (country_id)
        REFERENCES master_data.country(id) ON UPDATE RESTRICT ON DELETE SET NULL,
    CONSTRAINT chk_candidate_contact_email_lower CHECK (email = lower(email)),
    CONSTRAINT chk_candidate_contact_phone_e164 CHECK (phone IS NULL OR phone ~ '^\+[1-9]\d{1,14}$')
);

-- Partial unique indexes for active contact details (prevents blocking re-registration upon soft deletion)
CREATE UNIQUE INDEX uq_candidate_contact_active_profile ON profile.candidate_contact (candidate_profile_id) WHERE deleted_at IS NULL;
CREATE UNIQUE INDEX uq_candidate_contact_active_email ON profile.candidate_contact (email) WHERE deleted_at IS NULL;

-- Candidate Education
CREATE TABLE profile.candidate_education (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    candidate_profile_id bigint NOT NULL,
    education_level_id bigint NOT NULL,
    qualification_id bigint NULL,
    institution_name varchar(200) NOT NULL,
    qualification varchar(200) NULL,
    field_of_study varchar(200) NULL,
    start_date date NULL,
    end_date date NULL,
    grade_value numeric(6,2) NULL,
    grade_scale varchar(30) NULL,
    grade varchar(50) NULL,
    is_current boolean NOT NULL DEFAULT false,
    created_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_by bigint NULL,
    updated_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_by bigint NULL,
    deleted_at timestamptz NULL,
    CONSTRAINT fk_candidate_education_candidate_profile_id FOREIGN KEY (candidate_profile_id)
        REFERENCES profile.candidate_profile(id) ON UPDATE RESTRICT ON DELETE CASCADE,
    CONSTRAINT fk_candidate_education_education_level_id FOREIGN KEY (education_level_id)
        REFERENCES master_data.education_level(id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_candidate_education_qualification_id FOREIGN KEY (qualification_id)
        REFERENCES master_data.qualification(id) ON UPDATE RESTRICT ON DELETE SET NULL,
    CONSTRAINT chk_candidate_education_dates CHECK (end_date IS NULL OR start_date IS NULL OR end_date >= start_date)
);

-- Candidate Work Experience
CREATE TABLE profile.candidate_work_experience (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    candidate_profile_id bigint NOT NULL,
    company_name varchar(200) NOT NULL,
    job_title varchar(200) NOT NULL,
    employment_type_id bigint NULL,
    start_date date NULL,
    end_date date NULL,
    is_current boolean NOT NULL DEFAULT false,
    description varchar(3000) NULL,
    created_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_by bigint NULL,
    updated_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_by bigint NULL,
    deleted_at timestamptz NULL,
    CONSTRAINT fk_candidate_work_experience_candidate_profile_id FOREIGN KEY (candidate_profile_id)
        REFERENCES profile.candidate_profile(id) ON UPDATE RESTRICT ON DELETE CASCADE,
    CONSTRAINT fk_candidate_work_experience_employment_type_id FOREIGN KEY (employment_type_id)
        REFERENCES master_data.employment_type(id) ON UPDATE RESTRICT ON DELETE SET NULL,
    CONSTRAINT chk_candidate_work_experience_dates CHECK (end_date IS NULL OR start_date IS NULL OR end_date >= start_date)
);

-- Candidate Skills (Surrogate PK on junction table per Rule Group 2)
CREATE TABLE profile.candidate_skill (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    candidate_profile_id bigint NOT NULL,
    skill_id bigint NOT NULL,
    proficiency_level_id bigint NOT NULL,
    years_used numeric(4,1) NULL,
    created_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_by bigint NULL,
    updated_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_by bigint NULL,
    CONSTRAINT fk_candidate_skill_candidate_profile_id FOREIGN KEY (candidate_profile_id)
        REFERENCES profile.candidate_profile(id) ON UPDATE RESTRICT ON DELETE CASCADE,
    CONSTRAINT fk_candidate_skill_skill_id FOREIGN KEY (skill_id)
        REFERENCES master_data.skill(id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_candidate_skill_proficiency_level_id FOREIGN KEY (proficiency_level_id)
        REFERENCES master_data.proficiency_level(id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT uq_candidate_skill UNIQUE (candidate_profile_id, skill_id),
    CONSTRAINT chk_candidate_skill_years_used CHECK (years_used IS NULL OR years_used >= 0.0)
);

-- Candidate Languages (Surrogate PK on junction table per Rule Group 2)
CREATE TABLE profile.candidate_language (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    candidate_profile_id bigint NOT NULL,
    language_id bigint NOT NULL,
    proficiency_level_id bigint NOT NULL,
    created_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_by bigint NULL,
    updated_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_by bigint NULL,
    CONSTRAINT fk_candidate_language_candidate_profile_id FOREIGN KEY (candidate_profile_id)
        REFERENCES profile.candidate_profile(id) ON UPDATE RESTRICT ON DELETE CASCADE,
    CONSTRAINT fk_candidate_language_language_id FOREIGN KEY (language_id)
        REFERENCES master_data.language(id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_candidate_language_proficiency_level_id FOREIGN KEY (proficiency_level_id)
        REFERENCES master_data.proficiency_level(id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT uq_candidate_language UNIQUE (candidate_profile_id, language_id)
);

-- Profile Projects (Tier 1 Mandatory: role, duration, outcome per PRD Section 4)
CREATE TABLE profile.profile_project (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    candidate_profile_id bigint NOT NULL,
    project_title varchar(200) NOT NULL,
    role_name varchar(150) NOT NULL,
    start_date date NULL,
    end_date date NULL,
    outcome_summary varchar(2000) NULL,
    project_url varchar(500) NULL,
    created_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_by bigint NULL,
    updated_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_by bigint NULL,
    deleted_at timestamptz NULL,
    CONSTRAINT fk_profile_project_candidate_profile_id FOREIGN KEY (candidate_profile_id)
        REFERENCES profile.candidate_profile(id) ON UPDATE RESTRICT ON DELETE CASCADE,
    CONSTRAINT chk_profile_project_dates CHECK (end_date IS NULL OR start_date IS NULL OR end_date >= start_date)
);

-- Resume Templates (Tier 2: Resume versions and templates)
CREATE TABLE profile.resume_template (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    template_name varchar(100) NOT NULL,
    layout_format varchar(50) NOT NULL,
    is_active boolean NOT NULL DEFAULT true,
    created_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_by bigint NULL,
    updated_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_by bigint NULL,
    CONSTRAINT uq_resume_template_name UNIQUE (template_name)
);

-- Resume Documents (Tier 2: Versioning, template mapping, storage key, mime type, size, parsed body)
CREATE TABLE profile.resume_document (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    candidate_profile_id bigint NOT NULL,
    resume_template_id bigint NULL,
    version_number integer NOT NULL DEFAULT 1,
    title varchar(150) NOT NULL,
    file_uri varchar(500) NOT NULL,
    storage_key varchar(500) NULL,
    mime_type varchar(100) NOT NULL DEFAULT 'application/pdf',
    file_size_bytes bigint NULL,
    resume_body text NULL, -- Rule 3: Unbounded text justified for full parsed resume content
    content_language_id bigint NULL,
    is_primary boolean NOT NULL DEFAULT false,
    created_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_by bigint NULL,
    updated_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_by bigint NULL,
    deleted_at timestamptz NULL,
    CONSTRAINT fk_resume_document_candidate_profile_id FOREIGN KEY (candidate_profile_id)
        REFERENCES profile.candidate_profile(id) ON UPDATE RESTRICT ON DELETE CASCADE,
    CONSTRAINT fk_resume_document_template_id FOREIGN KEY (resume_template_id)
        REFERENCES profile.resume_template(id) ON UPDATE RESTRICT ON DELETE SET NULL,
    CONSTRAINT fk_resume_document_language_id FOREIGN KEY (content_language_id)
        REFERENCES master_data.language(id) ON UPDATE RESTRICT ON DELETE SET NULL,
    CONSTRAINT uq_resume_document_version UNIQUE (candidate_profile_id, version_number),
    CONSTRAINT chk_resume_document_size CHECK (file_size_bytes IS NULL OR (file_size_bytes >= 0 AND file_size_bytes <= 15728640)) -- 15MB upper bound per PRD Section 4
);

-- Professional Certifications
CREATE TABLE profile.candidate_certification (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    candidate_profile_id bigint NOT NULL,
    certification_name varchar(200) NOT NULL,
    issuer varchar(200) NULL,
    credential_id varchar(150) NULL,
    credential_url varchar(2048) NULL,
    issue_date date NULL,
    expiry_date date NULL,
    created_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_by bigint NULL,
    updated_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_by bigint NULL,
    deleted_at timestamptz NULL,
    CONSTRAINT fk_candidate_certification_candidate_profile_id FOREIGN KEY (candidate_profile_id)
        REFERENCES profile.candidate_profile(id) ON UPDATE RESTRICT ON DELETE CASCADE,
    CONSTRAINT chk_candidate_certification_expiry CHECK (expiry_date IS NULL OR issue_date IS NULL OR expiry_date >= issue_date)
);

-- Candidate Preferences (Target job role, preferred location, preferred employment type, min salary)
CREATE TABLE profile.candidate_preference (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    candidate_profile_id bigint NOT NULL,
    job_role_id bigint NULL,
    location_id bigint NULL,
    employment_type_id bigint NULL,
    work_type_id bigint NULL,
    minimum_salary numeric(14,2) NULL,
    salary_currency char(3) NULL,
    is_active boolean NOT NULL DEFAULT true,
    created_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_by bigint NULL,
    updated_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_by bigint NULL,
    deleted_at timestamptz NULL,
    CONSTRAINT fk_candidate_preference_candidate_profile_id FOREIGN KEY (candidate_profile_id)
        REFERENCES profile.candidate_profile(id) ON UPDATE RESTRICT ON DELETE CASCADE,
    CONSTRAINT fk_candidate_preference_job_role_id FOREIGN KEY (job_role_id)
        REFERENCES master_data.job_role(id) ON UPDATE RESTRICT ON DELETE SET NULL,
    CONSTRAINT fk_candidate_preference_location_id FOREIGN KEY (location_id)
        REFERENCES master_data.location(id) ON UPDATE RESTRICT ON DELETE SET NULL,
    CONSTRAINT fk_candidate_preference_employment_type_id FOREIGN KEY (employment_type_id)
        REFERENCES master_data.employment_type(id) ON UPDATE RESTRICT ON DELETE SET NULL,
    CONSTRAINT fk_candidate_preference_work_type_id FOREIGN KEY (work_type_id)
        REFERENCES master_data.work_type(id) ON UPDATE RESTRICT ON DELETE SET NULL,
    CONSTRAINT fk_candidate_preference_currency FOREIGN KEY (salary_currency)
        REFERENCES master_data.currency(code) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT chk_candidate_preference_salary CHECK (minimum_salary IS NULL OR minimum_salary >= 0.0)
);

-- Candidate Honors & Awards
CREATE TABLE profile.candidate_award (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    candidate_profile_id bigint NOT NULL,
    award_name varchar(200) NOT NULL,
    issuer varchar(200) NULL,
    award_date date NULL,
    description varchar(2000) NULL,
    created_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_by bigint NULL,
    updated_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_by bigint NULL,
    deleted_at timestamptz NULL,
    CONSTRAINT fk_candidate_award_candidate_profile_id FOREIGN KEY (candidate_profile_id)
        REFERENCES profile.candidate_profile(id) ON UPDATE RESTRICT ON DELETE CASCADE
);

-- Candidate Assessments & Scores (Tier 2)
CREATE TABLE profile.candidate_assessment (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    candidate_profile_id bigint NOT NULL,
    assessment_name varchar(200) NOT NULL,
    score numeric(5,2) NOT NULL,
    max_score numeric(5,2) NOT NULL DEFAULT 100.00,
    passed boolean NOT NULL DEFAULT true,
    completed_at timestamptz NOT NULL,
    created_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_by bigint NULL,
    updated_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_by bigint NULL,
    CONSTRAINT fk_candidate_assessment_candidate_profile_id FOREIGN KEY (candidate_profile_id)
        REFERENCES profile.candidate_profile(id) ON UPDATE RESTRICT ON DELETE CASCADE,
    CONSTRAINT chk_candidate_assessment_score CHECK (score >= 0.00 AND score <= max_score)
);

-- Candidate Course Enrolments (Tier 2)
CREATE TABLE profile.candidate_course (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    candidate_profile_id bigint NOT NULL,
    course_name varchar(200) NOT NULL,
    institution_name varchar(200) NOT NULL,
    completion_date date NULL,
    certificate_uri varchar(500) NULL,
    created_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_by bigint NULL,
    updated_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_by bigint NULL,
    CONSTRAINT fk_candidate_course_candidate_profile_id FOREIGN KEY (candidate_profile_id)
        REFERENCES profile.candidate_profile(id) ON UPDATE RESTRICT ON DELETE CASCADE
);

-- Candidate Bookmarks (Tier 2: Shortlist and bookmark history for employers and recruiters)
CREATE TABLE profile.candidate_bookmark (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    candidate_profile_id bigint NOT NULL,
    bookmarked_by_user_id bigint NULL,
    bookmarked_by_organisation_id bigint NULL,
    notes varchar(2000) NULL,
    bookmarked_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_by bigint NULL,
    updated_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_by bigint NULL,
    CONSTRAINT fk_candidate_bookmark_candidate_profile_id FOREIGN KEY (candidate_profile_id)
        REFERENCES profile.candidate_profile(id) ON UPDATE RESTRICT ON DELETE CASCADE
);

-- Candidate Referral Tracking (Tier 2: Referral tracking workflow)
CREATE TABLE profile.candidate_referral (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    candidate_profile_id bigint NOT NULL,
    referrer_user_id bigint NULL,
    referral_code varchar(50) NOT NULL,
    referral_status_id bigint NOT NULL,
    reward_amount numeric(12,2) NULL,
    reward_currency char(3) NULL,
    referred_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_by bigint NULL,
    updated_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_by bigint NULL,
    CONSTRAINT fk_candidate_referral_candidate_profile_id FOREIGN KEY (candidate_profile_id)
        REFERENCES profile.candidate_profile(id) ON UPDATE RESTRICT ON DELETE CASCADE,
    CONSTRAINT fk_candidate_referral_status_id FOREIGN KEY (referral_status_id)
        REFERENCES master_data.referral_status(id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_candidate_referral_currency FOREIGN KEY (reward_currency)
        REFERENCES master_data.currency(code) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT chk_candidate_referral_reward CHECK (reward_amount IS NULL OR reward_amount >= 0.0)
);

-- Profile View History (Tier 2 / Rule 10: Append-only view history with credit deduction)
CREATE TABLE profile.profile_view_history (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    candidate_profile_id bigint NOT NULL,
    viewer_user_id bigint NULL,
    viewer_organisation_id bigint NULL,
    viewed_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    credit_deducted integer NOT NULL DEFAULT 0,
    CONSTRAINT fk_profile_view_history_candidate_profile_id FOREIGN KEY (candidate_profile_id)
        REFERENCES profile.candidate_profile(id) ON UPDATE RESTRICT ON DELETE CASCADE,
    CONSTRAINT chk_profile_view_credit CHECK (credit_deducted >= 0)
);

-- Candidate Activity Log (Tier 2 / Rule 4: Append-only event tracking)
CREATE TABLE profile.candidate_activity_log (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    candidate_profile_id bigint NOT NULL,
    activity_type varchar(50) NOT NULL,
    activity_details varchar(1000) NULL,
    ip_address varchar(45) NULL,
    created_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT fk_candidate_activity_log_candidate_profile_id FOREIGN KEY (candidate_profile_id)
        REFERENCES profile.candidate_profile(id) ON UPDATE RESTRICT ON DELETE CASCADE
);


-- ============================================================================
-- MODULE 3: RECRUITMENT (JOBS AND APPLICATIONS)
-- Job requirements, positions, consultant openness, questionnaires,
-- options, applications, pipeline stages, multi-interviewer feedback, offers, shortlists,
-- and candidate job search history.
-- ============================================================================

-- Job Requirements
-- Rule 3: Unbounded text justified for job_description. Fixed-precision money with currency companion.
-- Rule 7: Entered content language recorded.
CREATE TABLE recruitment.job_requirement (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    organisation_id bigint NULL, -- Owning employer organisation
    created_by_user_id bigint NULL, -- Recruiter/hiring manager account who created the job
    job_title varchar(200) NOT NULL,
    job_description text NOT NULL, -- Rule 3: Unbounded text justified for job descriptions
    employment_type_id bigint NOT NULL,
    work_type_id bigint NOT NULL,
    industry_id bigint NULL,
    job_role_id bigint NULL,
    location_id bigint NULL,
    city_id bigint NULL,
    country_id bigint NOT NULL,
    positions_count integer NOT NULL DEFAULT 1,
    min_experience_years numeric(4,1) NULL,
    max_experience_years numeric(4,1) NULL,
    min_salary numeric(14,2) NULL,
    max_salary numeric(14,2) NULL,
    currency_code char(3) NULL,
    status_id bigint NOT NULL,
    is_open_to_consultants boolean NOT NULL DEFAULT false, -- Section 3 business rule
    content_language_id bigint NULL,
    published_at timestamptz NULL,
    closes_at timestamptz NULL,
    created_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_by bigint NULL,
    updated_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_by bigint NULL,
    deleted_at timestamptz NULL,
    CONSTRAINT fk_job_requirement_employment_type_id FOREIGN KEY (employment_type_id)
        REFERENCES master_data.employment_type(id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_job_requirement_work_type_id FOREIGN KEY (work_type_id)
        REFERENCES master_data.work_type(id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_job_requirement_industry_id FOREIGN KEY (industry_id)
        REFERENCES master_data.industry(id) ON UPDATE RESTRICT ON DELETE SET NULL,
    CONSTRAINT fk_job_requirement_job_role_id FOREIGN KEY (job_role_id)
        REFERENCES master_data.job_role(id) ON UPDATE RESTRICT ON DELETE SET NULL,
    CONSTRAINT fk_job_requirement_location_id FOREIGN KEY (location_id)
        REFERENCES master_data.location(id) ON UPDATE RESTRICT ON DELETE SET NULL,
    CONSTRAINT fk_job_requirement_city_id FOREIGN KEY (city_id)
        REFERENCES master_data.city(id) ON UPDATE RESTRICT ON DELETE SET NULL,
    CONSTRAINT fk_job_requirement_country_id FOREIGN KEY (country_id)
        REFERENCES master_data.country(id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_job_requirement_currency_code FOREIGN KEY (currency_code)
        REFERENCES master_data.currency(code) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_job_requirement_status_id FOREIGN KEY (status_id)
        REFERENCES master_data.job_requirement_status(id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_job_requirement_language_id FOREIGN KEY (content_language_id)
        REFERENCES master_data.language(id) ON UPDATE RESTRICT ON DELETE SET NULL,
    CONSTRAINT chk_job_requirement_positions CHECK (positions_count > 0),
    CONSTRAINT chk_job_requirement_experience CHECK (
        (max_experience_years IS NULL OR min_experience_years IS NULL OR max_experience_years >= min_experience_years)
        AND (min_experience_years IS NULL OR min_experience_years >= 0.0)
        AND (max_experience_years IS NULL OR max_experience_years >= 0.0)
    ),
    CONSTRAINT chk_job_requirement_salary CHECK (
        (max_salary IS NULL OR min_salary IS NULL OR max_salary >= min_salary)
        AND (min_salary IS NULL OR min_salary >= 0.0)
        AND (max_salary IS NULL OR max_salary >= 0.0)
    )
);

-- Job Requirement Skills Mapping
CREATE TABLE recruitment.job_requirement_skill (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    job_requirement_id bigint NOT NULL,
    skill_id bigint NOT NULL,
    is_mandatory boolean NOT NULL DEFAULT true,
    min_years_experience numeric(4,1) NULL,
    created_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_by bigint NULL,
    updated_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_by bigint NULL,
    CONSTRAINT fk_job_requirement_skill_job_requirement_id FOREIGN KEY (job_requirement_id)
        REFERENCES recruitment.job_requirement(id) ON UPDATE RESTRICT ON DELETE CASCADE,
    CONSTRAINT fk_job_requirement_skill_skill_id FOREIGN KEY (skill_id)
        REFERENCES master_data.skill(id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT uq_job_requirement_skill UNIQUE (job_requirement_id, skill_id),
    CONSTRAINT chk_job_requirement_skill_experience CHECK (min_years_experience IS NULL OR min_years_experience >= 0.0)
);

-- Job Questionnaire Attached to Job Requirements (Core Workflow)
CREATE TABLE recruitment.job_questionnaire (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    job_requirement_id bigint NOT NULL,
    title varchar(200) NOT NULL,
    instructions varchar(2000) NULL,
    version_number integer NOT NULL DEFAULT 1,
    is_mandatory boolean NOT NULL DEFAULT false,
    is_active boolean NOT NULL DEFAULT true,
    created_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_by bigint NULL,
    updated_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_by bigint NULL,
    deleted_at timestamptz NULL,
    CONSTRAINT fk_job_questionnaire_job_requirement_id FOREIGN KEY (job_requirement_id)
        REFERENCES recruitment.job_requirement(id) ON UPDATE RESTRICT ON DELETE CASCADE,
    CONSTRAINT uq_job_questionnaire_job_version
        UNIQUE (job_requirement_id, version_number),
    CONSTRAINT chk_job_questionnaire_version
        CHECK (version_number > 0)
);

-- Questionnaire Questions
CREATE TABLE recruitment.job_question (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    job_questionnaire_id bigint NOT NULL,
    question_text varchar(1000) NOT NULL,
    question_type_id bigint NOT NULL,
    is_required boolean NOT NULL DEFAULT true,
    sort_order integer NOT NULL DEFAULT 1,
    created_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_by bigint NULL,
    updated_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_by bigint NULL,
    CONSTRAINT fk_job_question_job_questionnaire_id FOREIGN KEY (job_questionnaire_id)
        REFERENCES recruitment.job_questionnaire(id) ON UPDATE RESTRICT ON DELETE CASCADE,
    CONSTRAINT fk_job_question_question_type_id FOREIGN KEY (question_type_id)
        REFERENCES master_data.question_type(id) ON UPDATE RESTRICT ON DELETE RESTRICT
);

-- Questionnaire Predefined Options (For single choice and multiple choice questions)
CREATE TABLE recruitment.job_question_option (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    job_question_id bigint NOT NULL,
    option_text varchar(500) NOT NULL,
    sort_order integer NOT NULL DEFAULT 1,
    created_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_by bigint NULL,
    updated_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_by bigint NULL,
    CONSTRAINT fk_job_question_option_question_id FOREIGN KEY (job_question_id)
        REFERENCES recruitment.job_question(id) ON UPDATE RESTRICT ON DELETE CASCADE
);

-- Job Applications (Applications and Pipeline)
CREATE TABLE recruitment.job_application (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    job_requirement_id bigint NOT NULL,
    candidate_profile_id bigint NOT NULL,
    selected_resume_document_id bigint NULL,
    status_id bigint NOT NULL,
    source_code varchar(30) NOT NULL DEFAULT 'direct',
    cover_letter varchar(4000) NULL, -- Bounded free text
    applied_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_by bigint NULL,
    updated_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_by bigint NULL,
    deleted_at timestamptz NULL,
    CONSTRAINT fk_job_application_job_requirement_id FOREIGN KEY (job_requirement_id)
        REFERENCES recruitment.job_requirement(id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_job_application_candidate_profile_id FOREIGN KEY (candidate_profile_id)
        REFERENCES profile.candidate_profile(id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_job_application_resume_document_id FOREIGN KEY (selected_resume_document_id)
        REFERENCES profile.resume_document(id) ON UPDATE RESTRICT ON DELETE SET NULL,
    CONSTRAINT fk_job_application_status_id FOREIGN KEY (status_id)
        REFERENCES master_data.application_status(id) ON UPDATE RESTRICT ON DELETE RESTRICT
);

-- Partial unique index for active applications (supports re-application upon soft-deletion or cooling period)
CREATE UNIQUE INDEX uq_job_application_active_candidate ON recruitment.job_application (job_requirement_id, candidate_profile_id) WHERE deleted_at IS NULL;

-- Candidate Questionnaire Answers
CREATE TABLE recruitment.candidate_question_answer (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    job_application_id bigint NOT NULL,
    job_question_id bigint NOT NULL,
    selected_option_id bigint NULL,
    answer_text varchar(4000) NOT NULL,
    created_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_by bigint NULL,
    updated_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_by bigint NULL,
    CONSTRAINT fk_candidate_question_answer_application_id FOREIGN KEY (job_application_id)
        REFERENCES recruitment.job_application(id) ON UPDATE RESTRICT ON DELETE CASCADE,
    CONSTRAINT fk_candidate_question_answer_question_id FOREIGN KEY (job_question_id)
        REFERENCES recruitment.job_question(id) ON UPDATE RESTRICT ON DELETE CASCADE,
    CONSTRAINT fk_candidate_question_answer_option_id FOREIGN KEY (selected_option_id)
        REFERENCES recruitment.job_question_option(id) ON UPDATE RESTRICT ON DELETE SET NULL,
    CONSTRAINT uq_candidate_question_answer UNIQUE (job_application_id, job_question_id)
);

-- Job Shortlist (Surrogate PK on junction table per Rule Group 2)
CREATE TABLE recruitment.job_shortlist (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    job_requirement_id bigint NOT NULL,
    candidate_profile_id bigint NOT NULL,
    shortlisted_by bigint NULL,
    notes varchar(2000) NULL,
    shortlisted_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_by bigint NULL,
    updated_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_by bigint NULL,
    CONSTRAINT fk_job_shortlist_job_requirement_id FOREIGN KEY (job_requirement_id)
        REFERENCES recruitment.job_requirement(id) ON UPDATE RESTRICT ON DELETE CASCADE,
    CONSTRAINT fk_job_shortlist_candidate_profile_id FOREIGN KEY (candidate_profile_id)
        REFERENCES profile.candidate_profile(id) ON UPDATE RESTRICT ON DELETE CASCADE,
    CONSTRAINT uq_job_shortlist UNIQUE (job_requirement_id, candidate_profile_id)
);

-- Job Interviews (Scheduled rounds across pipeline)
CREATE TABLE recruitment.job_interview (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    job_application_id bigint NOT NULL,
    interview_type_id bigint NOT NULL,
    status_id bigint NOT NULL,
    interview_round integer NOT NULL DEFAULT 1,
    mode_code varchar(30) NOT NULL DEFAULT 'video',
    meeting_reference varchar(500) NULL,
    interviewer_name varchar(150) NULL,
    scheduled_at timestamptz NOT NULL,
    completed_at timestamptz NULL,
    feedback varchar(4000) NULL,
    rating integer NULL,
    created_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_by bigint NULL,
    updated_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_by bigint NULL,
    deleted_at timestamptz NULL,
    CONSTRAINT fk_job_interview_job_application_id FOREIGN KEY (job_application_id)
        REFERENCES recruitment.job_application(id) ON UPDATE RESTRICT ON DELETE CASCADE,
    CONSTRAINT fk_job_interview_interview_type_id FOREIGN KEY (interview_type_id)
        REFERENCES master_data.interview_type(id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_job_interview_status_id FOREIGN KEY (status_id)
        REFERENCES master_data.interview_status(id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT chk_job_interview_round CHECK (interview_round > 0),
    CONSTRAINT chk_job_interview_dates CHECK (completed_at IS NULL OR completed_at >= scheduled_at),
    CONSTRAINT chk_job_interview_rating CHECK (rating IS NULL OR (rating >= 1 AND rating <= 5))
);

-- Interview Multi-Panel Feedback (Independent scoring per interviewer on a panel)
CREATE TABLE recruitment.interview_feedback (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    job_interview_id bigint NOT NULL,
    interviewer_user_id bigint NULL,
    interviewer_name varchar(150) NULL,
    technical_rating smallint NULL,
    communication_rating smallint NULL,
    problem_solving_rating smallint NULL,
    overall_rating numeric(3,1) NULL,
    recommendation_code varchar(30) NULL, -- strong_hire, hire, no_hire, strong_no_hire
    feedback_text varchar(4000) NULL,
    created_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_by bigint NULL,
    updated_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_by bigint NULL,
    CONSTRAINT fk_interview_feedback_job_interview_id FOREIGN KEY (job_interview_id)
        REFERENCES recruitment.job_interview(id) ON UPDATE RESTRICT ON DELETE CASCADE,
    CONSTRAINT chk_feedback_technical CHECK (technical_rating IS NULL OR (technical_rating >= 1 AND technical_rating <= 5)),
    CONSTRAINT chk_feedback_communication CHECK (communication_rating IS NULL OR (communication_rating >= 1 AND communication_rating <= 5)),
    CONSTRAINT chk_feedback_problem_solving CHECK (problem_solving_rating IS NULL OR (problem_solving_rating >= 1 AND problem_solving_rating <= 5)),
    CONSTRAINT chk_feedback_overall CHECK (overall_rating IS NULL OR (overall_rating >= 1.0 AND overall_rating <= 5.0))
);

-- Job Offers (Pipeline offer stage)
CREATE TABLE recruitment.job_offer (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    job_application_id bigint NOT NULL,
    salary_amount numeric(14,2) NOT NULL,
    salary_currency char(3) NOT NULL,
    status_id bigint NOT NULL,
    offered_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    expires_at timestamptz NULL,
    responded_at timestamptz NULL,
    created_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_by bigint NULL,
    updated_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_by bigint NULL,
    deleted_at timestamptz NULL,
    CONSTRAINT fk_job_offer_job_application_id FOREIGN KEY (job_application_id)
        REFERENCES recruitment.job_application(id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_job_offer_salary_currency FOREIGN KEY (salary_currency)
        REFERENCES master_data.currency(code) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_job_offer_status_id FOREIGN KEY (status_id)
        REFERENCES master_data.offer_status(id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT chk_job_offer_salary_amount CHECK (salary_amount >= 0.0),
    CONSTRAINT chk_job_offer_dates CHECK (expires_at IS NULL OR expires_at >= offered_at)
);

-- Application Status History (Rule 4 & Rule 10: Append-only audit history)
CREATE TABLE recruitment.application_status_history (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    job_application_id bigint NOT NULL,
    from_status_id bigint NULL,
    to_status_id bigint NOT NULL,
    changed_by_user_id bigint NULL,
    changed_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    reason_code varchar(50) NULL,
    notes varchar(2000) NULL,
    CONSTRAINT fk_application_status_history_application_id FOREIGN KEY (job_application_id)
        REFERENCES recruitment.job_application(id) ON UPDATE RESTRICT ON DELETE CASCADE,
    CONSTRAINT fk_application_status_history_from_status FOREIGN KEY (from_status_id)
        REFERENCES master_data.application_status(id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_application_status_history_to_status FOREIGN KEY (to_status_id)
        REFERENCES master_data.application_status(id) ON UPDATE RESTRICT ON DELETE RESTRICT
);

-- Candidate Job Search History (Tier 2 / PRD Section 4 & 6: Job search and application history)
CREATE TABLE recruitment.candidate_job_search_history (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    candidate_profile_id bigint NOT NULL,
    search_keywords varchar(255) NULL,
    city_id bigint NULL,
    industry_id bigint NULL,
    work_type_id bigint NULL,
    results_count integer NOT NULL DEFAULT 0,
    searched_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT fk_candidate_job_search_candidate_profile_id FOREIGN KEY (candidate_profile_id)
        REFERENCES profile.candidate_profile(id) ON UPDATE RESTRICT ON DELETE CASCADE,
    CONSTRAINT fk_candidate_job_search_city_id FOREIGN KEY (city_id)
        REFERENCES master_data.city(id) ON UPDATE RESTRICT ON DELETE SET NULL,
    CONSTRAINT fk_candidate_job_search_industry_id FOREIGN KEY (industry_id)
        REFERENCES master_data.industry(id) ON UPDATE RESTRICT ON DELETE SET NULL,
    CONSTRAINT fk_candidate_job_search_work_type_id FOREIGN KEY (work_type_id)
        REFERENCES master_data.work_type(id) ON UPDATE RESTRICT ON DELETE SET NULL,
    CONSTRAINT chk_candidate_job_search_results CHECK (results_count >= 0)
);


-- ============================================================================
-- AUTOMATED TRIGGERS (Rule Group 4 & Rule Group 10)
-- ============================================================================

-- updated_at maintenance triggers across all business entities
CREATE TRIGGER trg_location_updated_at BEFORE UPDATE ON master_data.location
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_qualification_updated_at BEFORE UPDATE ON master_data.qualification
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_candidate_profile_updated_at BEFORE UPDATE ON profile.candidate_profile
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_candidate_contact_updated_at BEFORE UPDATE ON profile.candidate_contact
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_candidate_education_updated_at BEFORE UPDATE ON profile.candidate_education
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_candidate_work_experience_updated_at BEFORE UPDATE ON profile.candidate_work_experience
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_candidate_skill_updated_at BEFORE UPDATE ON profile.candidate_skill
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_candidate_language_updated_at BEFORE UPDATE ON profile.candidate_language
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_profile_project_updated_at BEFORE UPDATE ON profile.profile_project
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_resume_document_updated_at BEFORE UPDATE ON profile.resume_document
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_candidate_certification_updated_at BEFORE UPDATE ON profile.candidate_certification
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_candidate_preference_updated_at BEFORE UPDATE ON profile.candidate_preference
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_candidate_award_updated_at BEFORE UPDATE ON profile.candidate_award
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_job_requirement_updated_at BEFORE UPDATE ON recruitment.job_requirement
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_job_application_updated_at BEFORE UPDATE ON recruitment.job_application
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_job_interview_updated_at BEFORE UPDATE ON recruitment.job_interview
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_interview_feedback_updated_at BEFORE UPDATE ON recruitment.interview_feedback
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_job_offer_updated_at BEFORE UPDATE ON recruitment.job_offer
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- Enforce append-only integrity on historical audit logs
CREATE TRIGGER trg_application_status_history_append_only BEFORE UPDATE OR DELETE ON recruitment.application_status_history
FOR EACH ROW EXECUTE FUNCTION enforce_append_only();

CREATE TRIGGER trg_profile_view_history_append_only BEFORE UPDATE OR DELETE ON profile.profile_view_history
FOR EACH ROW EXECUTE FUNCTION enforce_append_only();

CREATE TRIGGER trg_candidate_activity_log_append_only BEFORE UPDATE OR DELETE ON profile.candidate_activity_log
FOR EACH ROW EXECUTE FUNCTION enforce_append_only();

CREATE TRIGGER trg_candidate_job_search_history_append_only BEFORE UPDATE OR DELETE ON recruitment.candidate_job_search_history
FOR EACH ROW EXECUTE FUNCTION enforce_append_only();

-- ----------------------------------------------------------------------------
-- AUTOMATED PIPELINE STATUS AUDIT SYNCHRONIZATION (Single Source of Truth)
-- Ensures job_application.status_id and application_status_history never drift
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION recruitment.sync_application_status_history()
RETURNS TRIGGER AS $$
BEGIN
    IF (OLD.status_id IS DISTINCT FROM NEW.status_id) THEN
        INSERT INTO recruitment.application_status_history (
            job_application_id,
            from_status_id,
            to_status_id,
            changed_by_user_id,
            changed_at,
            reason_code,
            notes
        ) VALUES (
            NEW.id,
            OLD.status_id,
            NEW.status_id,
            NEW.updated_by,
            CURRENT_TIMESTAMP,
            'STATUS_TRANSITION',
            'Automated state transition recorded via job application update'
        );
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_job_application_status_sync
AFTER UPDATE OF status_id ON recruitment.job_application
FOR EACH ROW
EXECUTE FUNCTION recruitment.sync_application_status_history();



-- ============================================================================
-- INDEXES & HIGH-PERFORMANCE ACCESS PATHS (Page 8 of Design Pack)
-- Rule 1: Pattern idx_table_column
-- ============================================================================

-- Master Data Indexes
CREATE INDEX idx_state_country_id ON master_data.state USING btree (country_id);
CREATE INDEX idx_city_country_id ON master_data.city USING btree (country_id);
CREATE INDEX idx_city_state_id ON master_data.city USING btree (state_id);
CREATE INDEX idx_location_city_id ON master_data.location USING btree (city_id);
CREATE INDEX idx_qualification_education_level_id ON master_data.qualification USING btree (education_level_id);
CREATE INDEX idx_job_role_industry_id ON master_data.job_role USING btree (industry_id);
CREATE INDEX idx_ui_translation_key_id ON master_data.ui_translation USING btree (ui_translation_key_id);
CREATE INDEX idx_ui_translation_language_id ON master_data.ui_translation USING btree (language_id);

-- Profile Module Indexes
CREATE INDEX idx_candidate_profile_user_id ON profile.candidate_profile USING btree (user_id);
CREATE INDEX idx_candidate_contact_candidate_profile_id ON profile.candidate_contact USING btree (candidate_profile_id);
CREATE INDEX idx_candidate_contact_city_id ON profile.candidate_contact USING btree (city_id);
CREATE INDEX idx_candidate_education_candidate_profile_id ON profile.candidate_education USING btree (candidate_profile_id);
CREATE INDEX idx_candidate_work_experience_candidate_profile_id ON profile.candidate_work_experience USING btree (candidate_profile_id);
CREATE INDEX idx_candidate_skill_candidate_profile_id ON profile.candidate_skill USING btree (candidate_profile_id);
CREATE INDEX idx_candidate_skill_matching ON profile.candidate_skill USING btree (skill_id, candidate_profile_id); -- Skill-first matching index
CREATE INDEX idx_candidate_language_candidate_profile_id ON profile.candidate_language USING btree (candidate_profile_id);
CREATE INDEX idx_candidate_language_language_id ON profile.candidate_language USING btree (language_id);
CREATE INDEX idx_profile_project_candidate_profile_id ON profile.profile_project USING btree (candidate_profile_id);
CREATE INDEX idx_resume_document_candidate_profile_id ON profile.resume_document USING btree (candidate_profile_id);
CREATE INDEX idx_candidate_certification_candidate_profile_id ON profile.candidate_certification USING btree (candidate_profile_id);
CREATE INDEX idx_candidate_preference_candidate_profile_id ON profile.candidate_preference USING btree (candidate_profile_id);
CREATE INDEX idx_candidate_award_candidate_profile_id ON profile.candidate_award USING btree (candidate_profile_id);
CREATE INDEX idx_candidate_assessment_candidate_profile_id ON profile.candidate_assessment USING btree (candidate_profile_id);
CREATE INDEX idx_candidate_course_candidate_profile_id ON profile.candidate_course USING btree (candidate_profile_id);
CREATE INDEX idx_candidate_bookmark_candidate_profile_id ON profile.candidate_bookmark USING btree (candidate_profile_id);
CREATE INDEX idx_candidate_referral_candidate_profile_id ON profile.candidate_referral USING btree (candidate_profile_id);
CREATE INDEX idx_profile_view_history_candidate_profile_id ON profile.profile_view_history USING btree (candidate_profile_id);
CREATE INDEX idx_candidate_activity_log_candidate_profile_id ON profile.candidate_activity_log USING btree (candidate_profile_id);

-- Recruitment Module Indexes
CREATE INDEX idx_job_requirement_status_id ON recruitment.job_requirement USING btree (status_id);
CREATE INDEX idx_job_requirement_city_id ON recruitment.job_requirement USING btree (city_id);
CREATE INDEX idx_job_requirement_employment_type_id ON recruitment.job_requirement USING btree (employment_type_id);
CREATE INDEX idx_job_requirement_work_type_id ON recruitment.job_requirement USING btree (work_type_id);
CREATE INDEX idx_job_requirement_open_published ON recruitment.job_requirement USING btree (published_at DESC) WHERE deleted_at IS NULL; -- Partial index for active jobs
CREATE INDEX idx_job_requirement_skill_job_requirement_id ON recruitment.job_requirement_skill USING btree (job_requirement_id);
CREATE INDEX idx_job_requirement_skill_skill_id ON recruitment.job_requirement_skill USING btree (skill_id);
CREATE INDEX idx_job_questionnaire_job_requirement_id ON recruitment.job_questionnaire USING btree (job_requirement_id);
CREATE INDEX idx_job_question_job_questionnaire_id ON recruitment.job_question USING btree (job_questionnaire_id);
CREATE INDEX idx_job_question_option_job_question_id ON recruitment.job_question_option USING btree (job_question_id);
CREATE INDEX idx_job_application_pipeline ON recruitment.job_application USING btree (job_requirement_id, status_id); -- Recruiter pipeline index
CREATE INDEX idx_job_application_candidate_applied ON recruitment.job_application USING btree (candidate_profile_id, applied_at DESC); -- Candidate timeline index
CREATE INDEX idx_candidate_question_answer_application_id ON recruitment.candidate_question_answer USING btree (job_application_id);
CREATE INDEX idx_job_shortlist_job_requirement_id ON recruitment.job_shortlist USING btree (job_requirement_id);
CREATE INDEX idx_job_shortlist_candidate_profile_id ON recruitment.job_shortlist USING btree (candidate_profile_id);
CREATE INDEX idx_job_interview_job_application_id ON recruitment.job_interview USING btree (job_application_id);
CREATE INDEX idx_interview_feedback_job_interview_id ON recruitment.interview_feedback USING btree (job_interview_id);
CREATE INDEX idx_job_offer_job_application_id ON recruitment.job_offer USING btree (job_application_id);
CREATE INDEX idx_application_status_history_timeline ON recruitment.application_status_history USING btree (job_application_id, changed_at DESC); -- Chronological timeline index
CREATE INDEX idx_candidate_job_search_history_candidate_profile_id ON recruitment.candidate_job_search_history USING btree (candidate_profile_id);

-- ----------------------------------------------------------------------------
-- ADVANCED SEARCH & HIGH-FREQUENCY SCALE INDEXES (Full-Text, Trigram, Facets)
-- ----------------------------------------------------------------------------

-- 1. Full-Text Search (GIN tsvector) for multi-million scale keyword searching
CREATE INDEX idx_job_requirement_fts ON recruitment.job_requirement USING gin (to_tsvector('english', job_title || ' ' || coalesce(job_description, '')));
CREATE INDEX idx_candidate_profile_fts ON profile.candidate_profile USING gin (to_tsvector('english', coalesce(headline, '') || ' ' || coalesce(summary, '')));
CREATE INDEX idx_resume_document_fts ON profile.resume_document USING gin (to_tsvector('english', coalesce(resume_body, '')));

-- 2. High-Frequency Trigram Autocomplete (GIN gin_trgm_ops) for sub-millisecond typeahead
CREATE INDEX idx_skill_name_trgm ON master_data.skill USING gin (skill_name gin_trgm_ops);
CREATE INDEX idx_job_role_name_trgm ON master_data.job_role USING gin (role_name gin_trgm_ops);
CREATE INDEX idx_city_name_trgm ON master_data.city USING gin (name gin_trgm_ops);

-- 3. Composite & Faceted Search Indexes for high-concurrency filtering
CREATE INDEX idx_candidate_profile_search_facets ON profile.candidate_profile USING btree (years_experience, profile_completion_percentage, profile_visibility_code) WHERE deleted_at IS NULL;
CREATE INDEX idx_job_requirement_search_facets ON recruitment.job_requirement USING btree (city_id, industry_id, employment_type_id, min_salary, max_salary) WHERE deleted_at IS NULL;
CREATE INDEX idx_job_application_pipeline_triad ON recruitment.job_application USING btree (job_requirement_id, status_id, applied_at DESC);

-- 4. Search Telemetry & Analytics Access Paths
CREATE INDEX idx_candidate_job_search_history_timeline ON recruitment.candidate_job_search_history USING btree (searched_at DESC);
CREATE INDEX idx_candidate_job_search_history_city ON recruitment.candidate_job_search_history USING btree (city_id, searched_at DESC);



-- ============================================================================
-- SENSITIVE DATA CLASSIFICATIONS (Rule Group 6)
-- Explicit data taxonomy: Public, Internal, Personal, Sensitive
-- ============================================================================

-- Personal Data (Personal)
COMMENT ON COLUMN profile.candidate_profile.full_name IS 'Classification: Personal';
COMMENT ON COLUMN profile.candidate_profile.date_of_birth IS 'Classification: Personal';
COMMENT ON COLUMN profile.candidate_contact.email IS 'Classification: Personal';
COMMENT ON COLUMN profile.candidate_contact.phone IS 'Classification: Personal';
COMMENT ON COLUMN profile.candidate_contact.address_line IS 'Classification: Personal';
COMMENT ON COLUMN profile.candidate_contact.postal_code IS 'Classification: Personal';
COMMENT ON COLUMN profile.resume_document.resume_body IS 'Classification: Personal';
COMMENT ON COLUMN profile.resume_document.file_uri IS 'Classification: Personal';
COMMENT ON COLUMN profile.candidate_referral.referral_code IS 'Classification: Personal';

-- Sensitive Data (Sensitive)
COMMENT ON COLUMN recruitment.job_offer.salary_amount IS 'Classification: Sensitive';
COMMENT ON COLUMN recruitment.job_offer.salary_currency IS 'Classification: Sensitive';
COMMENT ON COLUMN profile.candidate_preference.minimum_salary IS 'Classification: Sensitive';
COMMENT ON COLUMN profile.candidate_referral.reward_amount IS 'Classification: Sensitive';

-- Internal Operational Data (Internal)
COMMENT ON COLUMN recruitment.job_interview.feedback IS 'Classification: Internal';
COMMENT ON COLUMN recruitment.job_interview.rating IS 'Classification: Internal';
COMMENT ON COLUMN recruitment.interview_feedback.feedback_text IS 'Classification: Internal';
COMMENT ON COLUMN recruitment.interview_feedback.overall_rating IS 'Classification: Internal';
COMMENT ON COLUMN recruitment.job_shortlist.notes IS 'Classification: Internal';
COMMENT ON COLUMN profile.candidate_bookmark.notes IS 'Classification: Internal';
COMMENT ON COLUMN recruitment.application_status_history.notes IS 'Classification: Internal';
COMMENT ON COLUMN profile.profile_view_history.viewer_user_id IS 'Classification: Internal';
COMMENT ON COLUMN profile.profile_view_history.credit_deducted IS 'Classification: Internal';
COMMENT ON COLUMN profile.candidate_activity_log.ip_address IS 'Classification: Internal';
COMMENT ON COLUMN recruitment.candidate_job_search_history.search_keywords IS 'Classification: Internal';

-- Public Catalog Data (Public)
COMMENT ON COLUMN master_data.country.name IS 'Classification: Public';
COMMENT ON COLUMN master_data.city.name IS 'Classification: Public';
COMMENT ON COLUMN master_data.skill.skill_name IS 'Classification: Public';
COMMENT ON COLUMN recruitment.job_requirement.job_title IS 'Classification: Public';
COMMENT ON COLUMN recruitment.job_requirement.job_description IS 'Classification: Public';
COMMENT ON COLUMN recruitment.job_question.question_text IS 'Classification: Public';
-- ============================================================
-- Phase 1 integrity hardening
-- Resume ownership, questionnaire answers, and job consistency
-- ============================================================

-- 1. A resume selected by an application must belong to that
--    application's candidate.
ALTER TABLE profile.resume_document
    ADD CONSTRAINT uq_resume_document_candidate_id
    UNIQUE (candidate_profile_id, id);

ALTER TABLE recruitment.job_application
    DROP CONSTRAINT IF EXISTS fk_job_application_resume_document_id;

ALTER TABLE recruitment.job_application
    ADD CONSTRAINT fk_job_application_candidate_resume
    FOREIGN KEY (candidate_profile_id, selected_resume_document_id)
    REFERENCES profile.resume_document (candidate_profile_id, id)
    ON UPDATE RESTRICT
    ON DELETE SET NULL (selected_resume_document_id);


-- 2. A selected answer option must belong to the question answered.
ALTER TABLE recruitment.job_question_option
    ADD CONSTRAINT uq_job_question_option_question_id
    UNIQUE (job_question_id, id);

ALTER TABLE recruitment.candidate_question_answer
    DROP CONSTRAINT IF EXISTS fk_candidate_question_answer_option_id;

ALTER TABLE recruitment.candidate_question_answer
    ADD CONSTRAINT fk_candidate_answer_question_option
    FOREIGN KEY (job_question_id, selected_option_id)
    REFERENCES recruitment.job_question_option (job_question_id, id)
    ON UPDATE RESTRICT
    ON DELETE SET NULL (selected_option_id);


-- 3. Validate that an answer's question belongs to a questionnaire
--    for the job attached to that application.
CREATE OR REPLACE FUNCTION recruitment.check_candidate_answer_questionnaire()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM recruitment.job_application AS ja
        JOIN recruitment.job_question AS jq
          ON jq.id = NEW.job_question_id
        JOIN recruitment.job_questionnaire AS qn
          ON qn.id = jq.job_questionnaire_id
        WHERE ja.id = NEW.job_application_id
          AND ja.job_requirement_id = qn.job_requirement_id
    ) THEN
        RAISE EXCEPTION
            'Question % does not belong to a questionnaire for the job on application %',
            NEW.job_question_id, NEW.job_application_id
            USING ERRCODE = '23514';
    END IF;

    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_candidate_answer_questionnaire_integrity
BEFORE INSERT OR UPDATE OF job_application_id, job_question_id
ON recruitment.candidate_question_answer
FOR EACH ROW
EXECUTE FUNCTION recruitment.check_candidate_answer_questionnaire();


-- 4. Prevent changing an application's job if its existing answers
--    would then refer to questions for a different job.
CREATE OR REPLACE FUNCTION recruitment.check_application_questionnaire_consistency()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM recruitment.candidate_question_answer AS ca
        JOIN recruitment.job_question AS jq
          ON jq.id = ca.job_question_id
        JOIN recruitment.job_questionnaire AS qn
          ON qn.id = jq.job_questionnaire_id
        WHERE ca.job_application_id = NEW.id
          AND qn.job_requirement_id <> NEW.job_requirement_id
    ) THEN
        RAISE EXCEPTION
            'Changing job on application % would invalidate its questionnaire answers',
            NEW.id
            USING ERRCODE = '23514';
    END IF;

    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_application_questionnaire_consistency
BEFORE UPDATE OF job_requirement_id
ON recruitment.job_application
FOR EACH ROW
WHEN (OLD.job_requirement_id IS DISTINCT FROM NEW.job_requirement_id)
EXECUTE FUNCTION recruitment.check_application_questionnaire_consistency();


-- 5. Prevent moving an answered question to a questionnaire for a
--    different job.
CREATE OR REPLACE FUNCTION recruitment.check_question_questionnaire_consistency()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
    new_questionnaire_job_id bigint;
BEGIN
    SELECT qn.job_requirement_id
      INTO new_questionnaire_job_id
    FROM recruitment.job_questionnaire AS qn
    WHERE qn.id = NEW.job_questionnaire_id;

    IF EXISTS (
        SELECT 1
        FROM recruitment.candidate_question_answer AS ca
        JOIN recruitment.job_application AS ja
          ON ja.id = ca.job_application_id
        WHERE ca.job_question_id = NEW.id
          AND ja.job_requirement_id <> new_questionnaire_job_id
    ) THEN
        RAISE EXCEPTION
            'Moving question % would invalidate existing questionnaire answers',
            NEW.id
            USING ERRCODE = '23514';
    END IF;

    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_question_questionnaire_consistency
BEFORE UPDATE OF job_questionnaire_id
ON recruitment.job_question
FOR EACH ROW
WHEN (OLD.job_questionnaire_id IS DISTINCT FROM NEW.job_questionnaire_id)
EXECUTE FUNCTION recruitment.check_question_questionnaire_consistency();


-- 6. Prevent changing a questionnaire's job when answered questions
--    in that questionnaire would become inconsistent.
CREATE OR REPLACE FUNCTION recruitment.check_questionnaire_job_consistency()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM recruitment.job_question AS jq
        JOIN recruitment.candidate_question_answer AS ca
          ON ca.job_question_id = jq.id
        JOIN recruitment.job_application AS ja
          ON ja.id = ca.job_application_id
        WHERE jq.job_questionnaire_id = NEW.id
          AND ja.job_requirement_id <> NEW.job_requirement_id
    ) THEN
        RAISE EXCEPTION
            'Changing job on questionnaire % would invalidate existing answers',
            NEW.id
            USING ERRCODE = '23514';
    END IF;

    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_questionnaire_job_consistency
BEFORE UPDATE OF job_requirement_id
ON recruitment.job_questionnaire
FOR EACH ROW
WHEN (OLD.job_requirement_id IS DISTINCT FROM NEW.job_requirement_id)
EXECUTE FUNCTION recruitment.check_questionnaire_job_consistency();

-- High-Performance Full-Text & Trigram Fuzzy Search (Rule Group 8)
CREATE INDEX idx_job_requirement_title_trgm ON recruitment.job_requirement USING gin (job_title gin_trgm_ops);

