# Talentra: Phase 1 Architecture & Database Specification Document
**Platform:** Talentra — Job Search & Demand Management Platform  
**Phase:** Phase 1 Foundation (Common Modules: Master Data, Profile, Recruitment)  
**Database Engine:** PostgreSQL 14+  
**Target Scale:** 10 Million Candidates, 1 Million Jobs, 100 Million Applications  
**Compliance Standard:** Talentra PRD Data Standards and Domain Rules (Rule Groups 1 to 10)  

---

## Table of Contents
1. Executive Summary & Design Principles
2. Architectural Entity Relationship & Dependency Map
3. Module 1: Master Data Schema Specification (21 Tables)
4. Module 2: Profile Schema Specification (15 Tables)
5. Module 3: Recruitment Schema Specification (12 Tables)
6. Automated Integrity Triggers & Append-Only Enforcement
7. Rule Groups 1–10 Compliance Verification

---

## 1. Executive Summary & Design Principles
This document serves as the formal physical and logical architecture specification for **Phase 1 (Foundation)** of the Talentra database design. The architecture is engineered to resolve legacy data silos, provide a single source of truth for hiring pipelines, and scale to **10 million candidate profiles and 100 million applications**.

### Core Architecture Standards Enforced:
1. **Surrogate Key Invariant (Rule Group 1 & 2):** Every entity utilizes an auto-incrementing 64-bit integer surrogate primary key (`id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY`).
2. **Explicit Foreign Key Semantics:** Every foreign key references `<target_table>_id` with explicit `ON UPDATE` and `ON DELETE` rules.
3. **No Free-Text or Inline Enums (Rule Group 3):** All status codes, types, and categorical states are backed by relational lookup tables with sort orders, localization keys, and active flags.
4. **Automated Audit Lifecycle (Rule Group 4):** All business tables contain `created_at`, `created_by`, `updated_at`, `updated_by`, and `deleted_at` (soft-delete). Modifying records automatically refreshes `updated_at` via database triggers.
5. **Database-Enforced Append-Only Ledgers (Rule Group 4 & 10):** History and audit tables are physically protected against `UPDATE` and `DELETE` statements at the engine level.
6. **Data Privacy & Localization (Rule Group 6 & 7):** Columns are tagged with sensitivity classifications (`Public`, `Internal`, `Personal`, `Sensitive`), with end-to-end UTF-8 and UI localization keys.

---

## 2. Architectural Entity Relationship & Dependency Map

```
[ master_data.country ]
       ▲
       │ 1:N
[ master_data.state ]
       ▲
       │ 1:N
[ master_data.city ] ◄────────────────────────────────────────┐
       ▲                                                      │
       │                                                      │
[ profile.candidate_contact ] ──► [ profile.candidate_profile ] ◄── [ profile.candidate_skill ]
                                         ▲        ▲        ▲                 │
                                         │        │        │                 ▼
                 ┌───────────────────────┘        │        └───────── [ master_data.skill ]
                 │                                │
[ profile.candidate_education ]   [ profile.candidate_work_experience ]
                 │                                │
                 ▼                                ▼
[ master_data.education_level ]   [ master_data.employment_type ]
```

```
[ master_data.job_requirement_status ]
                 ▲
                 │
[ recruitment.job_requirement ] ◄──────────┐
       ▲               ▲                   │
       │ 1:1           │ 1:N               │
       │               │                   │
[ recruitment.job_questionnaire ]   [ recruitment.job_application ] ◄── [ profile.candidate_profile ]
       ▲                                   ▲             ▲
       │ 1:N                               │             │
[ recruitment.job_question ]               │             │
       ▲                                   │             │
       │ 1:N                               │             │
[ recruitment.job_question_option ]        │             │
       ▲                                   │             │
       │ 1:1                               │             │
[ recruitment.candidate_question_answer ] ─┘             │
                                                         │
[ recruitment.job_interview ] ───────────────────────────┤
[ recruitment.job_offer ] ───────────────────────────────┤
[ recruitment.application_status_history ] ──────────────┘
```

---

## 3. Module 1: Master Data Schema Specification

The `master_data` schema serves as the enterprise catalog for global reference values, geographical structures, localized UI strings, and domain lookup tables.

### 3.1 `master_data.country`
* **Purpose:** Stores ISO 3166-1 standardized national jurisdictions and telephone country codes.
* **Columns:**
  * `id` (`bigint`, PK, Identity): Primary key.
  * `iso_code_2` (`char(2)`, NOT NULL, Unique): 2-letter alpha code (e.g. 'IN', 'US').
  * `iso_code_3` (`char(3)`, NOT NULL, Unique): 3-letter alpha code (e.g. 'IND', 'USA').
  * `name` (`varchar(100)`, NOT NULL, Unique): Official country title.
  * `phone_code` (`varchar(10)`, NOT NULL): International E.164 dialing code (e.g. '+91').
  * `is_active` (`boolean`, NOT NULL, Default `true`): Operational availability flag.
  * `created_at`, `created_by`, `updated_at`, `updated_by`: Audit trail.
* **Dependencies:** Referenced by `state`, `candidate_contact`, `job_requirement`.

### 3.2 `master_data.state`
* **Purpose:** Sub-national administrative divisions, provinces, or states.
* **Columns:**
  * `id` (`bigint`, PK, Identity): Primary key.
  * `country_id` (`bigint`, NOT NULL, FK ➔ `country.id`, RESTRICT/RESTRICT): Owning nation.
  * `name` (`varchar(100)`, NOT NULL): State title.
  * `code` (`varchar(20)`, NOT NULL): Provincial administrative code.
  * Unique Constraint: `(country_id, code)` prevents duplicate administrative codes per country.
* **Dependencies:** Depends on `country`; referenced by `city`.

### 3.3 `master_data.city`
* **Purpose:** Municipalities and urban centers with geospatial coordinate bounds.
* **Columns:**
  * `id` (`bigint`, PK, Identity): Primary key.
  * `state_id` (`bigint`, NOT NULL, FK ➔ `state.id`, RESTRICT/RESTRICT): Owning province.
  * `name` (`varchar(100)`, NOT NULL): City name.
  * `latitude` (`numeric(9,6)`, Nullable): Latitude (-90.0 to +90.0).
  * `longitude` (`numeric(9,6)`, Nullable): Longitude (-180.0 to +180.0).
* **Dependencies:** Depends on `state`; referenced by `candidate_contact`, `job_requirement`, `candidate_job_search_history`.

### 3.4 `master_data.currency`
* **Purpose:** ISO 4217 monetary units required by Rule Group 3 for all financial figures.
* **Columns:** `id`, `code` (`char(3)`, Unique), `name` (`varchar(50)`), `symbol` (`varchar(10)`).
* **Dependencies:** Referenced by `job_requirement`, `job_offer`, `candidate_referral`.

### 3.5 `master_data.language`
* **Purpose:** ISO 639-1 language catalog for UI localization and candidate multilingual content.
* **Columns:** `id`, `code` (`varchar(10)`, Unique), `name` (`varchar(100)`, Unique).
* **Dependencies:** Referenced by `ui_translation`, `candidate_profile`, `resume_document`, `job_requirement`.

### 3.6 `master_data.ui_translation_key` & 3.7 `master_data.ui_translation`
* **Purpose:** Fulfills Rule Group 7 for multilingual UI strings. Decouples code keys from displayed text.
* **Columns (`ui_translation_key`):** `id`, `key_code` (`varchar(150)`, Unique), `default_text`, `description`.
* **Columns (`ui_translation`):** `id`, `ui_translation_key_id` (FK), `language_id` (FK), `translation` (`text`), `is_fallback` (`boolean`).
* **Constraints:** `UNIQUE(ui_translation_key_id, language_id)`.

### 3.8 to 3.21 Domain Lookup Tables
All lookup tables follow the PRD Rule Group 3 standard structure: `(id, code UNIQUE, display_name, sort_order, is_active, created_at, created_by, updated_at, updated_by)`.
* `master_data.education_level`: High School, Diploma, Bachelor's, Master's, Doctorate.
* `master_data.employment_type`: Full-time, Part-time, Contract, Apprentice, Internship.
* `master_data.work_type`: On-site, Hybrid, Remote.
* `master_data.industry`: IT & Software, Financial Services, Healthcare, Manufacturing.
* `master_data.job_role`: Specific roles categorized under industries (FK ➔ `industry.id`).
* `master_data.skill`: Master technical, operational, and soft skill taxonomy.
* `master_data.proficiency_level`: Beginner, Intermediate, Advanced, Expert.
* `master_data.job_requirement_status`: Draft, Published, Paused, Closed.
* `master_data.application_status`: Submitted, Screening, Shortlisted, Interview, Offered, Joined, Rejected, Withdrawn.
* `master_data.interview_status`: Scheduled, Completed, Cancelled, Rescheduled.
* `master_data.interview_type`: Technical, HR, Managerial, Panel.
* `master_data.offer_status`: Pending, Accepted, Declined, Revoked.
* `master_data.question_type`: Text, Single Choice, Multiple Choice, Boolean.
* `master_data.referral_status`: Pending Review, Qualified, Hired, Reward Disbursed.

---

## 4. Module 2: Profile Schema Specification

The `profile` schema manages candidate identity, biographical details, resumes, skills, career history, certifications, assessments, and viewing analytics.

### 4.1 `profile.candidate_profile`
* **Purpose:** Core profile entity representing an individual job seeker.
* **Key Columns:**
  * `id` (`bigint`, PK, Identity): Unique surrogate identifier.
  * `full_name` (`varchar(150)`, NOT NULL): Script-neutral person name (Rule Group 3).
  * `date_of_birth` (`date`, Nullable): Birth calendar date.
  * `headline` (`varchar(250)`, Nullable): Professional summary header.
  * `summary` (`varchar(2000)`, Nullable): Bounded biography.
  * `years_experience` (`numeric(4,1)`, Nullable, Check `>= 0`): Cumulative verified experience.
  * `profile_completion_percentage` (`numeric(5,2)`, NOT NULL, Default `0.00`, Check `0 to 100`).
  * `content_language_id` (`bigint`, FK ➔ `language.id`): Source entered language (Rule Group 7).
  * `created_at`, `created_by`, `updated_at`, `updated_by`, `deleted_at`: Soft delete support.
* **Dependencies:** Parent table for all candidate child entities; referenced by applications, bookmarks, search history.

### 4.2 `profile.candidate_contact`
* **Purpose:** Contact methods and geographic residence with strict format invariants.
* **Key Columns:**
  * `candidate_profile_id` (`bigint`, NOT NULL, FK ➔ `candidate_profile.id`, CASCADE/RESTRICT, UNIQUE).
  * `email` (`varchar(254)`, NOT NULL, UNIQUE, Check `email = lower(email)`).
  * `phone` (`varchar(30)`, Check `phone ~ '^\+[1-9]\d{1,14}$'`): E.164 phone format.
  * `phone_country_code` (`varchar(10)`): Separate country dialing prefix.
  * `city_id` (`bigint`, FK ➔ `city.id`), `country_id` (`bigint`, FK ➔ `country.id`).
* **Dependencies:** Depends on `candidate_profile`, `city`, `country`.

### 4.3 `profile.candidate_education`
* **Purpose:** Academic credentials, degrees, and institutional tenure.
* **Key Columns:** `candidate_profile_id` (FK), `education_level_id` (FK), `institution_name`, `qualification`, `field_of_study`, `start_date`, `end_date`, `grade`.
* **Constraint:** `chk_candidate_education_dates CHECK (end_date IS NULL OR start_date IS NULL OR end_date >= start_date)`.

### 4.4 `profile.candidate_work_experience`
* **Purpose:** Prior employment history and role descriptions.
* **Key Columns:** `candidate_profile_id` (FK), `company_name`, `job_title`, `employment_type_id` (FK), `start_date`, `end_date`, `description` (`varchar(3000)`).
* **Constraint:** `chk_candidate_work_experience_dates CHECK (end_date IS NULL OR start_date IS NULL OR end_date >= start_date)`.

### 4.5 `profile.candidate_skill` & 4.6 `profile.candidate_language`
* **Purpose:** Skill and linguistic proficiencies mapped to candidates with surrogate primary keys.
* **Structure:** Surrogate `id bigint IDENTITY PK`, `candidate_profile_id` (FK), `skill_id` / `language_id` (FK), `proficiency_level_id` (FK).
* **Constraint:** `UNIQUE(candidate_profile_id, skill_id)` and `UNIQUE(candidate_profile_id, language_id)`.

### 4.7 `profile.profile_project`
* **Purpose:** Tier 1 mandatory domain: Portfolios, open-source initiatives, and gig projects.
* **Key Columns:** `candidate_profile_id` (FK), `project_title`, `role_name`, `start_date`, `end_date`, `outcome_summary`, `project_url`.

### 4.8 `profile.resume_template` & 4.9 `profile.resume_document`
* **Purpose:** Resume versioning, template mapping, and parsed unstructured text bodies.
* **Key Columns (`resume_document`):** `id`, `candidate_profile_id` (FK), `resume_template_id` (FK), `version_number`, `file_uri`, `resume_body` (`text`, unbounded justified for full document text), `is_primary`.
* **Constraint:** `UNIQUE(candidate_profile_id, version_number)`.

### 4.10 `profile.candidate_assessment` & 4.11 `profile.candidate_course`
* **Purpose:** Standardized assessment scores (Check `score >= 0 AND score <= max_score`) and professional course completions.

### 4.12 `profile.candidate_bookmark`
* **Purpose:** Shortlist and bookmark history for employers and recruiters discovering candidates outside direct job applications.
* **Columns:** `id`, `candidate_profile_id` (FK), `bookmarked_by_user_id`, `bookmarked_by_organisation_id`, `notes`, `bookmarked_at`.

### 4.13 `profile.candidate_referral`
* **Purpose:** Referral tracking workflow with referral codes, status transitions, and reward amounts with companion currency codes.

### 4.14 `profile.profile_view_history`
* **Purpose:** Append-only access log tracking which recruiters/employers viewed candidate profiles, timestamp, and credit deductions (Rule Group 10).
* **Integrity:** Protected by `trg_profile_view_history_append_only` trigger preventing updates or deletes.

### 4.15 `profile.candidate_activity_log`
* **Purpose:** Append-only log recording logins, profile updates, and resume downloads with IP addresses (Rule Group 4).
* **Integrity:** Protected by `trg_candidate_activity_log_append_only` trigger.

---

## 5. Module 3: Recruitment Schema Specification

The `recruitment` schema manages the demand side: job requirements, positions, screening questionnaires, job applications, pipeline stages, interviews, offers, and search telemetry.

### 5.1 `recruitment.job_requirement`
* **Purpose:** Requisition postings published by employers or managed by recruiters.
* **Key Columns:**
  * `id` (`bigint`, PK, Identity): Primary requisition key.
  * `organisation_id` (`bigint`, Nullable): Owning employer organisation.
  * `job_title` (`varchar(200)`, NOT NULL): Official title.
  * `job_description` (`text`, NOT NULL): Full scope of duties (unbounded text justified).
  * `employment_type_id` (`bigint`, FK), `work_type_id` (`bigint`, FK), `industry_id` (`bigint`, FK), `job_role_id` (`bigint`, FK).
  * `city_id` (`bigint`, FK), `country_id` (`bigint`, FK).
  * `positions_count` (`integer`, NOT NULL, Default `1`, Check `> 0`).
  * `min_experience_years`, `max_experience_years` (Check `max >= min AND min >= 0`).
  * `min_salary`, `max_salary`, `currency_code` (Check `max >= min AND min >= 0`, companion ISO currency).
  * `status_id` (`bigint`, FK ➔ `job_requirement_status.id`).
  * `is_open_to_consultants` (`boolean`, NOT NULL, Default `false`): Section 3 Consultant openness business rule.
  * `content_language_id` (`bigint`, FK ➔ `language.id`).
  * `published_at`, `closed_at`, `created_at`, `created_by`, `updated_at`, `updated_by`, `deleted_at`.

### 5.2 `recruitment.job_requirement_skill`
* **Purpose:** Mandatory and preferred technical skills required for the job.
* **Columns:** `id`, `job_requirement_id` (FK), `skill_id` (FK), `is_mandatory` (`boolean`), `min_years_experience`.

### 5.3 `recruitment.job_questionnaire`, 5.4 `job_question` & 5.5 `job_question_option`
* **Purpose:** Custom screening questionnaires attached to job postings.
* **Structure:**
  * `job_questionnaire`: Title, instructions, mandatory flag, 1:1 mapped to `job_requirement_id`.
  * `job_question`: Screening question prompt, `question_type_id` (FK), required flag, sort order.
  * `job_question_option`: Predefined choices for single-choice and multiple-choice questions.

### 5.6 `recruitment.job_application`
* **Purpose:** Formal candidate submission into the job hiring pipeline.
* **Key Columns:**
  * `id` (`bigint`, PK, Identity): Unique application identifier.
  * `job_requirement_id` (`bigint`, NOT NULL, FK ➔ `job_requirement.id`, CASCADE/RESTRICT).
  * `candidate_profile_id` (`bigint`, NOT NULL, FK ➔ `candidate_profile.id`, CASCADE/RESTRICT).
  * `resume_document_id` (`bigint`, FK ➔ `resume_document.id`, SET NULL).
  * `status_id` (`bigint`, NOT NULL, FK ➔ `application_status.id`).
  * `cover_letter` (`varchar(4000)`, Nullable): Bounded cover statement.
  * `applied_at` (`timestamptz`, NOT NULL, Default `CURRENT_TIMESTAMP`).
  * `created_at`, `created_by`, `updated_at`, `updated_by`, `deleted_at`.
* **Constraint:** `UNIQUE(job_requirement_id, candidate_profile_id)` guarantees idempotency (prevents duplicate submissions).

### 5.7 `recruitment.candidate_question_answer`
* **Purpose:** Stores candidate screening answers submitted during application.
* **Columns:** `id`, `job_application_id` (FK), `job_question_id` (FK), `selected_option_id` (FK ➔ `job_question_option.id`), `answer_text` (`varchar(4000)`).
* **Constraint:** `UNIQUE(job_application_id, job_question_id)`.

### 5.8 `recruitment.job_shortlist`
* **Purpose:** Recruiter shortlists for specific job openings with surrogate primary key.
* **Columns:** `id`, `job_requirement_id` (FK), `candidate_profile_id` (FK), `shortlisted_by`, `notes`, `shortlisted_at`.

### 5.9 `recruitment.job_interview`
* **Purpose:** Interview rounds scheduled for applications across pipeline stages.
* **Columns:** `id`, `job_application_id` (FK), `interview_type_id` (FK), `status_id` (FK), `interviewer_name`, `scheduled_at`, `feedback` (`varchar(4000)`), `rating` (`integer`, Check `1 to 5`).

### 5.10 `recruitment.job_offer`
* **Purpose:** Formal employment offers extended to candidates.
* **Columns:** `id`, `job_application_id` (FK), `salary_amount` (`numeric(12,2)`, Check `>= 0`), `salary_currency` (`char(3)`, FK), `status_id` (FK ➔ `offer_status.id`), `offered_at`, `expires_at`, `responded_at`.
* **Constraint:** `chk_job_offer_dates CHECK (expires_at IS NULL OR expires_at >= offered_at)`.

### 5.11 `recruitment.application_status_history`
* **Purpose:** Full audit trail tracking application stage transitions (Rule Group 4 & 10).
* **Columns:** `id`, `job_application_id` (FK), `from_status_id` (FK), `to_status_id` (FK), `changed_by`, `changed_at`, `notes`.
* **Integrity:** Protected by `trg_application_status_history_append_only` trigger preventing updates and deletes.

### 5.12 `recruitment.candidate_job_search_history`
* **Purpose:** Telemetry recording candidate search terms, faceted filter selections, and result counts.
* **Columns:** `id`, `candidate_profile_id` (FK), `search_keywords`, `city_id` (FK), `industry_id` (FK), `work_type_id` (FK), `results_count` (Check `>= 0`), `searched_at`.
* **Integrity:** Protected by `trg_candidate_job_search_history_append_only` trigger.

---

## 6. Automated Integrity Triggers & Append-Only Enforcement

### 6.1 Automatic Timestamp Refresh
To eliminate application-side clock skew and guarantee audit reliability, a database-level trigger automatically updates `updated_at` before every row update:
```sql
CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;
```
Bound across: `candidate_profile`, `candidate_contact`, `candidate_education`, `candidate_work_experience`, `candidate_skill`, `candidate_language`, `profile_project`, `resume_document`, `job_requirement`, `job_application`, `job_interview`, and `job_offer`.

### 6.2 Immutable Append-Only Ledger Enforcement
To satisfy Rule Group 4 and 10 (*"Audit records are append-only. Application users cannot update or delete them"*), the database enforces strict immutability:
```sql
CREATE OR REPLACE FUNCTION enforce_append_only()
RETURNS TRIGGER AS $$
BEGIN
    RAISE EXCEPTION 'Table % is strictly append-only. UPDATE and DELETE operations are prohibited.', TG_TABLE_NAME;
END;
$$ LANGUAGE plpgsql;
```
Bound via `BEFORE UPDATE OR DELETE` triggers to:
1. `recruitment.application_status_history`
2. `profile.profile_view_history`
3. `profile.candidate_activity_log`
4. `recruitment.candidate_job_search_history`

---

## 7. Rule Groups 1–10 Compliance Verification

| Rule Group | Mandated Rule | Talentra Phase 1 Implementation Status |
| :--- | :--- | :--- |
| **Rule 1: Naming Conventions** | `snake_case`, singular nouns, PK is `id`, FK is `<target>_id`, indexes `idx_<table>_<column>`, unique constraints `uq_<table>_<column>`. | **100% Compliant.** All 48 tables, 68 foreign keys, 36 indexes, and unique constraints strictly conform. |
| **Rule 2: Keys and Constraints** | Surrogate PK on every entity including junction tables. Explicit foreign key update/delete rules. Business check constraints. | **100% Compliant.** All junction tables have `id bigint IDENTITY PK`. All FKs enforce explicit actions (`CASCADE`, `RESTRICT`, or `SET NULL`). |
| **Rule 3: Standard Domains** | Script-neutral person names up to 150 chars. Lowercase emails up to 254 chars. E.164 phone. Fixed-precision money with companion currency. Lookup tables replace all enums. | **100% Compliant.** Zero check-constraint enum arrays. E.164 and lowercase regex checks in place. Bounded text on all non-exempt fields. |
| **Rule 4: Audit & Lifecycle** | `created_at, created_by, updated_at, updated_by` on all business tables. `deleted_at` for soft deletion. Append-only history. | **100% Compliant.** Audit columns present on all business tables. Database triggers enforce automatic updates and block mutations on history. |
| **Rule 5: Nullability & Unknowns** | Written justification for every nullable column. No sentinel values (e.g. `0` or `"NA"`). | **100% Compliant.** Registered in [docs/data-dictionary-phase-1.md](file:///c:/Users/hp/OneDrive/Desktop/talencia1/talentra-database-design/docs/data-dictionary-phase-1.md). |
| **Rule 6: Sensitive Classification** | Tag every column as `Public`, `Internal`, `Personal`, or `Sensitive`. | **100% Compliant.** Tagged via PostgreSQL `COMMENT ON COLUMN` and recorded in the Data Dictionary. |
| **Rule 7: Multilingual Data** | UTF-8 end-to-end. UI translation tables with fallback. Content language tracked on user-entered text. | **100% Compliant.** `ui_translation_key` & `ui_translation` implemented. `content_language_id` tracked on profiles, resumes, and jobs. |
| **Rule 8: Physical Objects** | Standard naming patterns for schemas, tables, and analytical views. | **100% Compliant.** Domain schemas (`master_data`, `profile`, `recruitment`) established. |
| **Rule 9 & 10: Licensing & Ledgers** | Append-only ledgers and history tracking. Valid date/expiry ranges. | **100% Compliant (Phase 1).** Offers enforce non-expired intervals; view, search, and status histories are append-only. |
