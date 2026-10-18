# Phase 1: Foundation & Common Modules Design Documentation

**Engine:** PostgreSQL 14+  
**Team:** Panshul (Profile), Moksh (Jobs and Applications), Priyamvada (Master Data and cross-module coordination)  
**Status:** Phase 1 Design, Schema, and Seed Data Completed & Validated  

---

## Milestone 1: DB Provider & Module Assignments

### B1 — Database Provider Decision
* **Selected Database:** PostgreSQL
* **Rationale:** PostgreSQL provides first-class support for relational integrity, JSONB support for integration boundaries, generated identity keys, strict check constraints, btree indexing, and timezone-aware timestamps (`timestamptz`). It satisfies all hackathon sizing requirements (scaling from laptop-scale tests to 10M candidate projections).

### B2 — Agreed Module Scope
The team has aligned the database modularization with the hackathon project docket:
1. **Master Data** (Geographical entities, skills, languages, qualifications, UI translation keys, reference lookups)
2. **Profile** (Candidate identity, contact, education, experience, skills, languages, projects, resumes, assessments, view history, activity logs)
3. **Jobs and Applications** (Job requirements, positions, questionnaires, applications, shortlists, interviews, offers, status history)

### B3 — Responsibility Matrix
* **Priyamvada:** Master Data & Localization
* **Panshul:** Candidate Profile & Assessments
* **Moksh:** Jobs, Questionnaires, Applications & Pipeline

---

## Milestone 2: Entity Identification (B4 – B7)

### Master Data Entities
* `country`, `state`, `city`
* `currency`, `language`, `ui_translation_key`, `ui_translation`
* `education_level`, `employment_type`, `work_type`, `industry`, `job_role`, `skill`
* Standard lookup enumerations: `proficiency_level`, `job_requirement_status`, `application_status`, `interview_status`, `interview_type`, `offer_status`, `question_type`

### Profile Entities
* `candidate_profile`
* `candidate_contact`
* `candidate_education`
* `candidate_work_experience`
* `candidate_skill`
* `candidate_language`
* `profile_project`
* `resume_document`
* `candidate_assessment`
* `candidate_course`
* `profile_view_history`
* `candidate_activity_log`

### Jobs and Applications Entities
* `job_requirement`
* `job_requirement_skill`
* `job_questionnaire`
* `job_question`
* `job_application`
* `candidate_question_answer`
* `job_shortlist`
* `job_interview`
* `job_offer`
* `application_status_history`

---

## Milestone 3 & 4: Relationships & Standard Columns (B8 – B15)

### Relational Modeling Principles
1. **Surrogate Keys:** Every table is equipped with an auto-incrementing 64-bit integer surrogate primary key `id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY`.
2. **Standardized Foreign Keys:** Foreign keys consistently reference the target table name with the suffix `_id` (e.g. `candidate_profile_id`, `job_requirement_id`).
3. **No Inline Check Enums:** All status workflows and categorical domains are modeled as lookup tables in the `master_data` schema.
4. **Standard Audit Columns:** All core business entities feature `created_at`, `created_by`, `updated_at`, `updated_by`, and `deleted_at` for soft-deletion.
5. **Localization:** Multi-language UI is separated into `ui_translation_key` and `ui_translation`, while user-entered text documents store their origin `content_language_id`.

---

## Milestone 5 & 6: Keys, Constraints & Validation (B16 – B23)

* **Date Order Invariants:** CHECK constraints enforce `end_date >= start_date` on all education, work experience, and project entities.
* **Monetary Domains:** Salaried offerings and job budgets use fixed-precision `numeric(12,2)` coupled with an ISO 4217 companion currency code.
* **Phone & Email Formats:** Emails enforce lowercase consistency (`email = lower(email)`), and telephone numbers enforce international E.164 formatting (`^\+[1-9]\d{1,14}$`).
* **Indexes:** Explicit B-Tree indexes created on all foreign key columns following the `idx_<table>_<column>` standard pattern.

---

## Rule Compliance Checklist (Section 5)

| Rule Group | Status | Implementation Details |
| :--- | :---: | :--- |
| **1: Naming Conventions** | Compliant | All tables and columns use `snake_case`. Table names are singular nouns. Primary keys are named `id`. Foreign keys follow `<referenced_table>_id`. Indexes follow `idx_table_column` and unique constraints follow `uq_table_column`. |
| **2: Keys and Constraints** | Compliant | Surrogate keys (`bigint IDENTITY`) applied on all entities including junction tables. Natural keys enforced via `UNIQUE` constraints. Foreign keys enforce explicit `ON UPDATE` and `ON DELETE` rules. |
| **3: Standard Domains** | Compliant | Person name uses script-neutral `varchar(150)`. Emails capped at 254 chars with lowercase constraint. Phone numbers in E.164. Money stored as `numeric(12,2)` with companion currency code. Lookup tables replace all inline enums. Unbounded text restricted to job descriptions and resume bodies. |
| **4: Audit and Lifecycle** | Compliant | `created_at`, `created_by`, `updated_at`, `updated_by`, and `deleted_at` present on all business tables. Append-only logs for view and activity history. |
| **5: Nullability and Unknown Values** | Compliant | Unknown values are modeled distinctly from zero/empty strings; explicit nullability rules applied. |
| **6: Sensitive Data Classification** | Compliant | Columns tagged with PostgreSQL comments (`COMMENT ON COLUMN`) classifying fields as `Public`, `Internal`, `Personal`, or `Sensitive`. |
| **7: Multilingual Data** | Compliant | UTF-8 used end-to-end. UI translations held per key and language in `ui_translation`. User content captures `content_language_id`. |
| **8: Naming of Physical Objects** | Compliant | Table schemas partitioned by domain (`master_data`, `profile`, `recruitment`). |
| **9: Licensing, Devices & Sessions** | In Scope for Phase 2/3 | Architecture leaves hook points for user/licence mapping. |
| **10: Money, Subscriptions & History** | Compliant (Phase 1) | Application status and profile view histories are append-only. Offers enforce valid expiration bounds. |

---

## Milestone 7: Final Phase 1 Sign-Off (B23) & Phase 2 Readiness

### B1–B23 Deliverables Verification Register

| Deliverable Artifact | Description & Contents | Status | Sign-off Evidence |
| :--- | :--- | :---: | :--- |
| **Provider Decision Record (B1)** | PostgreSQL 14+ selected with engine rationale and sizing compatibility. | **Approved** | Documented in `docs/phase-1-foundation.md` |
| **Entity Inventory (B2–B7)** | 54 tables covering Master Data (23), Candidate Profile (18), Recruitment (13). | **Approved** | Documented in `docs/phase-1-architecture-specification.md` |
| **ER Relationship Model (B8–B11)** | Cardinalities, junction tables, and 1:1, 1:N foreign key cascades. | **Approved** | Full dependency diagram in architecture spec |
| **Data Dictionary & Register (B12–B15)** | Nullability justifications and 4-tier data classification tags. | **Approved** | Documented in `docs/data-dictionary-phase-1.md` |
| **Constraint & Index Register (B16–B22)** | PKs, FKs, unique/check constraints, date invariants, and 59 indexes. | **Approved** | DDL implemented in `sql/schema.sql` |
| **Automated Forensic Ledgers (B20–B22)**| PL/pgSQL append-only triggers preventing mutations on history. | **Approved** | Triggers in `sql/schema.sql` |
| **Final Phase 1 Sign-Off (B23)** | Formal team approval for transition to Phase 2. | **Approved** | Validated via `inspect_schema.py` |

---

## Phase 2 Integration Seams & Cross-Module Boundaries

Phase 1 establishes clean, decoupled landing spots for subsequent phases without circular dependencies:

1. **Authentication & Identity (`auth` module):**
   * `profile.candidate_profile.user_id` (`bigint NULL UNIQUE`): Connects candidate identity to shared account service upon user registration.
   * `recruitment.job_requirement.created_by_user_id`: Connects job postings to internal recruiter accounts.
   * `recruitment.interview_feedback.interviewer_user_id`: Links evaluations to interviewer accounts.

2. **Organisations & Employers (`organisation` module):**
   * `recruitment.job_requirement.organisation_id` (`bigint NULL`): Connects jobs to employer tenancy without hardcoding company profile logic in recruitment.
   * `profile.candidate_bookmark.bookmarked_by_organisation_id`: Connects candidate talent pools to recruiter organisations.

3. **Billing, Wallets & Financials (`billing` module):**
   * `profile.profile_view_history.credit_deducted`: Hooks directly into credit deduction/burn logic.
   * `profile.candidate_referral.reward_amount` & `reward_currency`: Connects into referral bounty payouts.

4. **Forensic Search & AI Matching (`search` / `matching` module):**
   * `recruitment.candidate_job_search_history`: Supplies telemetry data for search ranking and candidate recommendation models.
   * Partial indexes (`idx_job_requirement_open_published`, `idx_candidate_skill_matching`, GIN trigrams) ready for high-concurrency candidate matching.

