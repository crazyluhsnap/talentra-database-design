# Talentra Phase 1 Data Dictionary & Nullability Justification Register

**Scope:** Master Data, Profile, Recruitment (Phase 1 Foundation Complete)  
**Standard Compliance:** Rule Group 5 (Nullability & Unknown Values) & Rule Group 6 (Sensitive Data Classification)  
**Design Reference:** Phase 1 Foundation Proposed Design Pack (B1–B23)  

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
| `master_data.city` | `state_id` | `bigint` | Yes | Public | Null for unitary city-states (e.g., Singapore, Monaco) without sub-national provincial divisions. |
| `master_data.city` | `postal_code` | `varchar(20)` | Yes | Public | Cities with multiple postal code zones or locations without postal code mappings. |
| `master_data.city` | `latitude` | `numeric(9,6)` | Yes | Public | Optional for newly added municipalities awaiting exact geocoding. |
| `master_data.city` | `longitude` | `numeric(9,6)` | Yes | Public | Companion to latitude; null when exact coordinate boundaries are unresolved. |
| `master_data.location` | `city_id` | `bigint` | Yes | Public | Special economic zones or rural campuses spanning multiple municipal boundaries. |
| `master_data.location` | `latitude` / `longitude` | `numeric(9,6)` | Yes | Public | Optional when physical site coordinates are unverified. |
| `master_data.qualification` | `education_level_id` | `bigint` | Yes | Public | Custom or executive certifications that do not map to standard academic tier levels. |
| `master_data.qualification` | `qualification_code` | `varchar(40)` | Yes | Public | Emerging vocational or niche courses without a national accreditation acronym. |
| `master_data.industry` | `industry_code` | `varchar(40)` | Yes | Public | Secondary or niche industry sub-sectors without official NAICS/SIC codes. |
| `master_data.job_role` | `role_code` | `varchar(40)` | Yes | Public | Hybrid or cross-functional job roles without standard O*NET classification codes. |
| `master_data.skill` | `normalized_name` | `varchar(150)` | Yes | Public | Null when skill_name is already in canonical normalized format. |
| `master_data.ui_translation_key` | `description` | `varchar(255)` | Yes | Public | Optional contextual explanation for translators where UI key context is self-evident. |

### B. Profile Module
| Table | Column | Data Type | Nullable? | Classification | Written Justification for Nullability |
| :--- | :--- | :--- | :---: | :---: | :--- |
| `profile.candidate_profile` | `user_id` | `bigint` | Yes | Internal | Nullable before candidate activates their shared authentication account (pre-registered / sourced). |
| `profile.candidate_profile` | `date_of_birth` | `date` | Yes | Personal | Optional during initial fast registration; prevents age bias in initial blind screening. |
| `profile.candidate_profile` | `headline` | `varchar(250)` | Yes | Public | Not all candidates specify a professional tagline immediately upon signup. |
| `profile.candidate_profile` | `summary` | `varchar(2000)` | Yes | Public | Profile biography is optional; can be populated later during profile enrichment. |
| `profile.candidate_profile` | `country_id` / `city_id`| `bigint` | Yes | Personal | Optional during initial profile drafting before location preferences are specified. |
| `profile.candidate_profile` | `years_experience` | `numeric(4,1)` | Yes | Public | Null for fresh graduates/entry-level applicants before work experience is added. |
| `profile.candidate_profile` | `content_language_id`| `bigint` | Yes | Internal | Nullable when candidate enters multilingual text or origin language is unclassified. |
| `profile.candidate_profile` | `deleted_at` | `timestamptz` | Yes | Internal | Null indicates active status; non-null timestamp indicates soft deletion per Rule 4. |
| `profile.candidate_contact` | `phone` | `varchar(30)` | Yes | Personal | Candidates may register exclusively via email without immediately supplying phone. |
| `profile.candidate_contact` | `phone_country_code`| `varchar(10)` | Yes | Personal | Dependent on phone presence; null when phone number is omitted. |
| `profile.candidate_contact` | `city_id` / `country_id`| `bigint` | Yes | Personal | Candidate may choose not to disclose physical residence during initial discovery. |
| `profile.candidate_contact` | `address_line` | `varchar(255)`| Yes | Personal | Exact street address is only requested during post-offer background checks. |
| `profile.candidate_contact` | `postal_code` | `varchar(20)` | Yes | Personal | Optional when street address is omitted. |
| `profile.candidate_education` | `qualification_id` | `bigint` | Yes | Public | Specific degree title lookup is optional if candidate enters raw qualification text. |
| `profile.candidate_education` | `qualification` | `varchar(200)`| Yes | Public | Optional when education level is self-descriptive. |
| `profile.candidate_education` | `field_of_study` | `varchar(200)`| Yes | Public | Secondary schooling and general diplomas without distinct departmental majors. |
| `profile.candidate_education` | `start_date` | `date` | Yes | Public | Historical certifications may only record the completion/graduation date. |
| `profile.candidate_education` | `end_date` | `date` | Yes | Public | Null indicates the candidate is currently enrolled and actively pursuing the degree. |
| `profile.candidate_education` | `grade_value` | `numeric(6,2)`| Yes | Public | Academic grade is optional across universities that do not release numerical transcripts. |
| `profile.candidate_education` | `grade_scale` | `varchar(30)` | Yes | Public | Companion to grade_value; null when grade is omitted. |
| `profile.candidate_education` | `grade` | `varchar(50)` | Yes | Public | Raw transcript label (e.g. 'First Class with Distinction'). |
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
| `profile.resume_document` | `storage_key` | `varchar(500)`| Yes | Internal | Object storage key (S3/GCS); null during raw text entry before file upload. |
| `profile.resume_document` | `file_size_bytes` | `bigint` | Yes | Internal | File size is null for online profile-generated resumes. |
| `profile.resume_document` | `resume_body` | `text` | Yes | Personal | Asynchronous OCR / resume parsing may be pending or failed for non-OCR PDFs. |
| `profile.candidate_certification` | `issuer` | `varchar(200)`| Yes | Public | Self-issued or decentralized blockchain credentials without institutional authority. |
| `profile.candidate_certification` | `credential_id` | `varchar(150)`| Yes | Public | Non-accredited certificates without unique license serials. |
| `profile.candidate_certification` | `credential_url` | `varchar(2048)`| Yes | Public | Offline paper certificates without online verification endpoints. |
| `profile.candidate_certification` | `issue_date` / `expiry_date`| `date` | Yes | Public | Lifelong certifications (e.g. Red Hat, AWS Cloud Practitioner) with no expiration. |
| `profile.candidate_preference` | `job_role_id` | `bigint` | Yes | Internal | Candidate open to general roles across an industry rather than a single specific title. |
| `profile.candidate_preference` | `location_id` | `bigint` | Yes | Internal | Candidate open to nationwide or global assignments. |
| `profile.candidate_preference` | `minimum_salary` | `numeric(14,2)`| Yes | Sensitive | Candidate willing to negotiate compensation based on equity or benefits. |
| `profile.candidate_preference` | `salary_currency` | `char(3)` | Yes | Sensitive | Companion to minimum_salary; null when salary is open. |
| `profile.candidate_award` | `issuer` | `varchar(200)`| Yes | Public | Internal corporate or community honors where issuer is informal. |
| `profile.candidate_award` | `award_date` | `date` | Yes | Public | Recognition given for cumulative tenure without a calendar day stamp. |
| `profile.candidate_award` | `description` | `varchar(2000)`| Yes | Public | Award title may be completely self-explanatory (e.g. 'Employee of the Year'). |
| `profile.candidate_course` | `completion_date` | `date` | Yes | Public | Course may be in progress without final credential date. |
| `profile.candidate_course` | `certificate_uri` | `varchar(500)` | Yes | Public | Informal or offline institutional course without an electronic verification link. |
| `profile.candidate_bookmark` | `notes` | `varchar(2000)`| Yes | Internal | Recruiter may bookmark a profile with a 1-click action without drafting notes. |
| `profile.candidate_referral` | `reward_amount` | `numeric(12,2)`| Yes | Sensitive | Referrals without a financial bounty (e.g. peer endorsements) carry null reward. |
| `profile.candidate_referral` | `reward_currency`| `char(3)` | Yes | Sensitive | Companion to reward amount; null when reward amount is null. |

### C. Recruitment Module
| Table | Column | Data Type | Nullable? | Classification | Written Justification for Nullability |
| :--- | :--- | :--- | :---: | :---: | :--- |
| `recruitment.job_requirement` | `organisation_id` | `bigint` | Yes | Internal | Cross-module reference; null during preliminary drafting before company mapping. |
| `recruitment.job_requirement` | `created_by_user_id` | `bigint` | Yes | Internal | Job posted programmatically via system API without an individual recruiter user. |
| `recruitment.job_requirement` | `industry_id` | `bigint` | Yes | Public | Cross-functional roles (e.g., General Counsel) apply across multiple industries. |
| `recruitment.job_requirement` | `job_role_id` | `bigint` | Yes | Public | Specialized emerging titles may not map to a standard industry taxonomy role. |
| `recruitment.job_requirement` | `location_id` | `bigint` | Yes | Public | General postings without requirement for a specific physical tech park. |
| `recruitment.job_requirement` | `city_id` | `bigint` | Yes | Public | Fully remote positions do not mandate a physical city base. |
| `recruitment.job_requirement` | `min_experience_years` | `numeric(4,1)` | Yes | Public | Entry-level positions with no prerequisite minimum tenure. |
| `recruitment.job_requirement` | `max_experience_years` | `numeric(4,1)` | Yes | Public | Open-ended leadership roles with no upper cap on candidate seniority. |
| `recruitment.job_requirement` | `min_salary` / `max_salary` | `numeric(14,2)` | Yes | Sensitive | Employers reserving compensation as 'Competitive / Commensurate with Experience'. |
| `recruitment.job_requirement` | `currency_code` | `char(3)` | Yes | Sensitive | Null when salary range is intentionally undisclosed. |
| `recruitment.job_requirement` | `published_at` | `timestamptz` | Yes | Internal | Null when job requirement is in `draft` state prior to official release. |
| `recruitment.job_requirement` | `closes_at` | `timestamptz` | Yes | Internal | Rolling job openings without a hard calendar closing cutoff. |
| `recruitment.job_questionnaire` | `instructions` | `varchar(2000)`| Yes | Public | Optional when questionnaire title is self-explanatory. |
| `recruitment.job_application` | `selected_resume_document_id` | `bigint` | Yes | Personal | Direct 1-click applications utilizing parsed profile data without a file attachment. |
| `recruitment.job_application` | `cover_letter` | `varchar(4000)`| Yes | Personal | Optional submission when employers don't mandate formal cover letters. |
| `recruitment.job_interview` | `meeting_reference` | `varchar(500)`| Yes | Internal | Physical onsite interviews without an online conference URL. |
| `recruitment.job_interview` | `interviewer_name` | `varchar(150)` | Yes | Internal | Panel or group assessment where individual lead interviewer is unassigned. |
| `recruitment.job_interview` | `completed_at` | `timestamptz` | Yes | Internal | Upcoming scheduled interviews that have not yet taken place. |
| `recruitment.job_interview` | `feedback` | `varchar(4000)`| Yes | Internal | Scheduled upcoming interviews that have not yet occurred or pending notes. |
| `recruitment.job_interview` | `rating` | `integer` | Yes | Internal | Rating is recorded only after interview completion (1 to 5 scale). |
| `recruitment.interview_feedback` | `interviewer_user_id`| `bigint` | Yes | Internal | External guest interviewer without an internal platform account ID. |
| `recruitment.interview_feedback` | `technical_rating` | `smallint` | Yes | Internal | Soft-skill or HR culture rounds where technical evaluation is not assessed. |
| `recruitment.interview_feedback` | `communication_rating`| `smallint` | Yes | Internal | Written asynchronous code screenings without verbal evaluation. |
| `recruitment.interview_feedback` | `problem_solving_rating`| `smallint`| Yes | Internal | General informational interviews without algorithmic exercises. |
| `recruitment.interview_feedback` | `overall_rating` | `numeric(3,1)`| Yes | Internal | Optional aggregate score when individual section marks suffice. |
| `recruitment.interview_feedback` | `recommendation_code`| `varchar(30)` | Yes | Internal | Pending feedback drafting prior to final hiring committee submission. |
| `recruitment.job_offer` | `expires_at` | `timestamptz` | Yes | Sensitive | Rolling offers without a formal hard deadline. |
| `recruitment.job_offer` | `responded_at` | `timestamptz` | Yes | Sensitive | Null while candidate response is currently pending. |
| `recruitment.application_status_history`| `changed_by_user_id`| `bigint` | Yes | Internal | Automated system transitions (e.g., auto-rejection after expiration). |
| `recruitment.application_status_history`| `reason_code` | `varchar(50)` | Yes | Internal | Standard administrative transitions without special justification codes. |
| `recruitment.candidate_job_search_history` | `search_keywords` | `varchar(255)` | Yes | Internal | Filter-only searches (e.g. browsing all jobs in Bengaluru without a search keyword). |
