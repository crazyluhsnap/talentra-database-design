# Talentra Phase 1 Data Dictionary & Nullability Justification Register

**Scope:** Master Data, Profile, Recruitment (Phase 1 Foundation)  
**Standard Compliance:** Rule Group 5 (Nullability & Unknown Values) & Rule Group 6 (Sensitive Data Classification)

---

## 1. Sensitive Data Classification Standards (Rule Group 6)
Every column across all tables is classified according to the following 4 tiers:
* **Public:** Non-confidential catalog or reference data available without restriction.
* **Internal:** Available only to internal platform staff and the owning organisation.
* **Personal:** Identifies an individual person; requires access control and strict audit logging.
* **Sensitive:** Financial figures, salaries, ratings, credentials; requires masking/encryption.

---

## 2. Nullability Justifications & Data Taxonomy (Rule Group 5)

Sentinel values (such as `0`, `NA`, or empty strings `""`) are strictly prohibited in the Talentra schema. Below is the written justification for every nullable column in Phase 1:

### A. Master Data Module
| Table | Column | Data Type | Nullable? | Classification | Written Justification for Nullability |
| :--- | :--- | :--- | :---: | :---: | :--- |
| `master_data.city` | `latitude` | `numeric(9,6)` | Yes | Public | Coordinates are optional for rural or newly added municipalities awaiting geocoding. |
| `master_data.city` | `longitude` | `numeric(9,6)` | Yes | Public | Companion to latitude; null when exact coordinate boundaries are unresolved. |
| `master_data.ui_translation_key` | `description` | `varchar(255)` | Yes | Public | Optional contextual explanation for translators where UI key context is self-evident. |

### B. Profile Module
| Table | Column | Data Type | Nullable? | Classification | Written Justification for Nullability |
| :--- | :--- | :--- | :---: | :---: | :--- |
| `profile.candidate_profile` | `date_of_birth` | `date` | Yes | Personal | Optional during initial fast registration; prevents age bias in initial blind screening. |
| `profile.candidate_profile` | `headline` | `varchar(250)` | Yes | Public | Not all candidates specify a professional tagline immediately upon signup. |
| `profile.candidate_profile` | `summary` | `varchar(2000)` | Yes | Public | Profile biography is optional; can be populated later during profile enrichment. |
| `profile.candidate_profile` | `years_experience` | `numeric(4,1)` | Yes | Public | Null for fresh graduates/entry-level applicants before work experience is added. |
| `profile.candidate_profile` | `content_language_id`| `bigint` | Yes | Internal | Nullable when candidate enters multilingual text or origin language is unclassified. |
| `profile.candidate_profile` | `deleted_at` | `timestamptz` | Yes | Internal | Null indicates active status; non-null timestamp indicates soft deletion per Rule 4. |
| `profile.candidate_contact` | `phone` | `varchar(30)` | Yes | Personal | Candidates may register exclusively via email without immediately supplying phone. |
| `profile.candidate_contact` | `phone_country_code`| `varchar(10)` | Yes | Personal | Dependent on phone presence; null when phone number is omitted. |
| `profile.candidate_contact` | `city_id` | `bigint` | Yes | Personal | Candidate may choose not to disclose physical city during initial discovery. |
| `profile.candidate_contact` | `country_id` | `bigint` | Yes | Personal | Optional for international remote candidates before formal onboarding. |
| `profile.candidate_contact` | `address_line` | `varchar(255)`| Yes | Personal | Exact street address is only requested during post-offer background checks. |
| `profile.candidate_contact` | `postal_code` | `varchar(20)` | Yes | Personal | Optional when street address is omitted. |
| `profile.candidate_education` | `qualification` | `varchar(200)`| Yes | Public | Specific degree title (e.g., "Honors") is optional when level is already specified. |
| `profile.candidate_education` | `field_of_study` | `varchar(200)`| Yes | Public | Certain secondary or diploma courses do not divide into distinct specialized majors. |
| `profile.candidate_education` | `start_date` | `date` | Yes | Public | Historical certifications may only record the completion/graduation date. |
| `profile.candidate_education` | `end_date` | `date` | Yes | Public | Null indicates the candidate is currently enrolled and actively pursuing the degree. |
| `profile.candidate_education` | `grade` | `varchar(50)` | Yes | Public | GPA/percentage reporting is non-mandatory across international universities. |
| `profile.candidate_work_experience`| `employment_type_id`| `bigint` | Yes | Public | Past legacy employers may not distinguish contract from full-time classifications. |
| `profile.candidate_work_experience`| `start_date` | `date` | Yes | Public | Candidate may only recall approximate duration or end date for short freelance gigs. |
| `profile.candidate_work_experience`| `end_date` | `date` | Yes | Public | Null explicitly represents current ongoing employment. |
| `profile.candidate_work_experience`| `description` | `varchar(3000)`| Yes | Public | Job duties description is optional when title and company are self-descriptive. |
| `profile.candidate_skill` | `years_used` | `numeric(4,1)` | Yes | Public | Skill exposure may be theoretical, academic, or self-taught without tracked tenure. |
| `profile.profile_project` | `start_date` | `date` | Yes | Public | Hackathon or short open-source projects may be completed on a single target date. |
| `profile.profile_project` | `end_date` | `date` | Yes | Public | Null represents ongoing, active open-source or portfolio initiatives. |
| `profile.profile_project` | `outcome_summary` | `varchar(2000)`| Yes | Public | Metric-driven outcomes are optional for personal exploratory prototypes. |
| `profile.profile_project` | `project_url` | `varchar(500)` | Yes | Public | Proprietary or offline project repositories without a publicly accessible web URL. |
| `profile.resume_document` | `resume_template_id`| `bigint` | Yes | Internal | Null when candidate uploads an unformatted raw PDF/DOCX document. |
| `profile.resume_document` | `resume_body` | `text` | Yes | Personal | Asynchronous OCR / resume parsing may be pending or failed for non-OCR PDFs. |
| `profile.candidate_course` | `completion_date` | `date` | Yes | Public | Course may be in progress without final credential date. |
| `profile.candidate_course` | `certificate_uri` | `varchar(500)` | Yes | Public | Informal or offline institutional course without an electronic verification link. |
| `profile.candidate_bookmark` | `notes` | `varchar(2000)`| Yes | Internal | Recruiter may bookmark a profile with a 1-click action without drafting notes. |
| `profile.candidate_referral` | `reward_amount` | `numeric(12,2)`| Yes | Sensitive | Referrals without a financial bounty (e.g. peer endorsements) carry null reward. |
| `profile.candidate_referral` | `reward_currency`| `char(3)` | Yes | Sensitive | Companion to reward amount; null when reward amount is null. |

### C. Recruitment Module
| Table | Column | Data Type | Nullable? | Classification | Written Justification for Nullability |
| :--- | :--- | :--- | :---: | :---: | :--- |
| `recruitment.job_requirement` | `industry_id` | `bigint` | Yes | Public | Cross-functional roles (e.g., General Counsel) apply across multiple industries. |
| `recruitment.job_requirement` | `job_role_id` | `bigint` | Yes | Public | Specialized emerging titles may not map to a standard industry taxonomy role. |
| `recruitment.job_requirement` | `city_id` | `bigint` | Yes | Public | Fully remote positions do not mandate a physical city base. |
| `recruitment.job_requirement` | `min_experience_years` | `numeric(4,1)` | Yes | Public | Entry-level positions with no prerequisite minimum tenure. |
| `recruitment.job_requirement` | `max_experience_years` | `numeric(4,1)` | Yes | Public | Open-ended leadership roles with no upper cap on candidate seniority. |
| `recruitment.job_requirement` | `min_salary` | `numeric(12,2)` | Yes | Sensitive | Employers reserving compensation as "Competitive / Commensurate with Experience". |
| `recruitment.job_requirement` | `max_salary` | `numeric(12,2)` | Yes | Sensitive | Uncapped performance/commission roles or undisclosed salary bands. |
| `recruitment.job_requirement` | `currency_code` | `char(3)` | Yes | Sensitive | Null when salary range is intentionally undisclosed. |
| `recruitment.job_requirement` | `published_at` | `timestamptz` | Yes | Internal | Null when job requirement is in `draft` state prior to official release. |
| `recruitment.job_requirement` | `closed_at` | `timestamptz` | Yes | Internal | Null while job posting remains open for candidate applications. |
| `recruitment.job_questionnaire` | `instructions` | `varchar(2000)`| Yes | Public | Optional when questionnaire title is self-explanatory. |
| `recruitment.job_application` | `resume_document_id` | `bigint` | Yes | Personal | Direct 1-click applications utilizing parsed profile data without a file attachment. |
| `recruitment.job_application` | `cover_letter` | `varchar(4000)`| Yes | Personal | Optional submission when employers don't mandate formal cover letters. |
| `recruitment.job_interview` | `interviewer_name` | `varchar(150)` | Yes | Internal | Panel or group assessment where individual lead interviewer is unassigned. |
| `recruitment.job_interview` | `feedback` | `varchar(4000)`| Yes | Internal | Scheduled upcoming interviews that have not yet occurred or pending notes. |
| `recruitment.job_interview` | `rating` | `integer` | Yes | Internal | Rating is recorded only after interview completion (1 to 5 scale). |
| `recruitment.job_offer` | `expires_at` | `timestamptz` | Yes | Sensitive | Rolling offers without a formal hard deadline. |
| `recruitment.job_offer` | `responded_at` | `timestamptz` | Yes | Sensitive | Null while candidate response is currently pending. |
| `recruitment.candidate_job_search_history` | `search_keywords` | `varchar(255)` | Yes | Internal | Filter-only searches (e.g. browsing all jobs in Bengaluru without a search keyword). |
