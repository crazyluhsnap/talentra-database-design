-- ============================================================================
-- Talentra: Phase 1 Seed Data
-- Populates Master Data lookups, geographical entities, reference enumerations,
-- localized UI strings, candidate profiles, templates, job requirements,
-- questionnaires, options, applications, interviews, feedback, bookmarks, and search history.
-- ============================================================================

BEGIN;

-- ----------------------------------------------------------------------------
-- 1. MASTER DATA: COUNTRIES & CURRENCIES
-- ----------------------------------------------------------------------------
INSERT INTO master_data.country (iso_code_2, iso_code_3, name, phone_code)
VALUES 
    ('IN', 'IND', 'India', '+91'),
    ('US', 'USA', 'United States', '+1'),
    ('GB', 'GBR', 'United Kingdom', '+44'),
    ('SG', 'SGP', 'Singapore', '+65')
ON CONFLICT (iso_code_2) DO NOTHING;

INSERT INTO master_data.currency (code, name, symbol)
VALUES 
    ('INR', 'Indian Rupee', '₹'),
    ('USD', 'US Dollar', '$'),
    ('GBP', 'British Pound', '£'),
    ('EUR', 'Euro', '€')
ON CONFLICT (code) DO NOTHING;

-- ----------------------------------------------------------------------------
-- 2. MASTER DATA: STATES, CITIES & LOCATIONS
-- ----------------------------------------------------------------------------
INSERT INTO master_data.state (country_id, name, code)
SELECT c.id, 'Delhi', 'DL' FROM master_data.country c WHERE c.iso_code_2 = 'IN'
ON CONFLICT (country_id, code) DO NOTHING;

INSERT INTO master_data.state (country_id, name, code)
SELECT c.id, 'Karnataka', 'KA' FROM master_data.country c WHERE c.iso_code_2 = 'IN'
ON CONFLICT (country_id, code) DO NOTHING;

INSERT INTO master_data.state (country_id, name, code)
SELECT c.id, 'California', 'CA' FROM master_data.country c WHERE c.iso_code_2 = 'US'
ON CONFLICT (country_id, code) DO NOTHING;

INSERT INTO master_data.city (country_id, state_id, name, postal_code, latitude, longitude)
SELECT c.id, s.id, 'New Delhi', '110001', 28.613900, 77.209000
FROM master_data.country c
JOIN master_data.state s ON s.country_id = c.id AND s.code = 'DL'
WHERE c.iso_code_2 = 'IN' AND NOT EXISTS (SELECT 1 FROM master_data.city WHERE name = 'New Delhi');

INSERT INTO master_data.city (country_id, state_id, name, postal_code, latitude, longitude)
SELECT c.id, s.id, 'Bengaluru', '560001', 12.971600, 77.594600
FROM master_data.country c
JOIN master_data.state s ON s.country_id = c.id AND s.code = 'KA'
WHERE c.iso_code_2 = 'IN' AND NOT EXISTS (SELECT 1 FROM master_data.city WHERE name = 'Bengaluru');

INSERT INTO master_data.city (country_id, state_id, name, postal_code, latitude, longitude)
SELECT c.id, s.id, 'San Francisco', '94102', 37.774900, -122.419400
FROM master_data.country c
JOIN master_data.state s ON s.country_id = c.id AND s.code = 'CA'
WHERE c.iso_code_2 = 'US' AND NOT EXISTS (SELECT 1 FROM master_data.city WHERE name = 'San Francisco');

-- Direct city without state (e.g. Singapore)
INSERT INTO master_data.city (country_id, state_id, name, postal_code, latitude, longitude)
SELECT c.id, NULL, 'Singapore City', '018989', 1.352100, 103.819800
FROM master_data.country c
WHERE c.iso_code_2 = 'SG' AND NOT EXISTS (SELECT 1 FROM master_data.city WHERE name = 'Singapore City');

-- Specific Office Location / Tech Park
INSERT INTO master_data.location (country_id, city_id, location_name, latitude, longitude)
SELECT ct.country_id, ct.id, 'EcoWorld Tech Park - Tower 4', 12.923400, 77.683500
FROM master_data.city ct
WHERE ct.name = 'Bengaluru'
AND NOT EXISTS (SELECT 1 FROM master_data.location WHERE location_name = 'EcoWorld Tech Park - Tower 4');

-- ----------------------------------------------------------------------------
-- 3. MASTER DATA: LANGUAGES & UI TRANSLATIONS
-- ----------------------------------------------------------------------------
INSERT INTO master_data.language (code, name)
VALUES 
    ('en', 'English'),
    ('hi', 'Hindi'),
    ('es', 'Spanish'),
    ('fr', 'French')
ON CONFLICT (code) DO NOTHING;

INSERT INTO master_data.ui_translation_key (key_code, default_text, description)
VALUES 
    ('nav.job_search', 'Find Jobs', 'Navigation link for job search'),
    ('btn.apply_now', 'Apply Now', 'Call to action button on job posting'),
    ('status.applied', 'Application Submitted', 'Status notification label')
ON CONFLICT (key_code) DO NOTHING;

INSERT INTO master_data.ui_translation (ui_translation_key_id, language_id, translation, is_fallback)
SELECT k.id, l.id, 'Find Jobs', true
FROM master_data.ui_translation_key k CROSS JOIN master_data.language l
WHERE k.key_code = 'nav.job_search' AND l.code = 'en'
ON CONFLICT DO NOTHING;

INSERT INTO master_data.ui_translation (ui_translation_key_id, language_id, translation, is_fallback)
SELECT k.id, l.id, 'नौकरियां खोजें', false
FROM master_data.ui_translation_key k CROSS JOIN master_data.language l
WHERE k.key_code = 'nav.job_search' AND l.code = 'hi'
ON CONFLICT DO NOTHING;

-- ----------------------------------------------------------------------------
-- 4. MASTER DATA: DOMAIN LOOKUPS & QUALIFICATIONS
-- ----------------------------------------------------------------------------
INSERT INTO master_data.education_level (level_name, sort_order)
VALUES 
    ('High School', 1),
    ('Diploma', 2),
    ('Bachelor''s Degree', 3),
    ('Master''s Degree', 4),
    ('Doctorate / PhD', 5)
ON CONFLICT (level_name) DO NOTHING;

INSERT INTO master_data.qualification (education_level_id, qualification_name, qualification_code)
SELECT el.id, 'Bachelor of Technology (B.Tech)', 'BTECH'
FROM master_data.education_level el WHERE el.level_name = 'Bachelor''s Degree'
ON CONFLICT (qualification_name) DO NOTHING;

INSERT INTO master_data.qualification (education_level_id, qualification_name, qualification_code)
SELECT el.id, 'Master of Science (M.S.)', 'MS'
FROM master_data.education_level el WHERE el.level_name = 'Master''s Degree'
ON CONFLICT (qualification_name) DO NOTHING;

INSERT INTO master_data.employment_type (type_name)
VALUES 
    ('Full-time'),
    ('Part-time'),
    ('Contract'),
    ('Apprentice'),
    ('Internship')
ON CONFLICT (type_name) DO NOTHING;

INSERT INTO master_data.work_type (type_name)
VALUES 
    ('On-site'),
    ('Hybrid'),
    ('Remote')
ON CONFLICT (type_name) DO NOTHING;

INSERT INTO master_data.industry (industry_name, industry_code)
VALUES 
    ('Information Technology & Software', 'IT_SW'),
    ('Banking & Financial Services', 'BFSI'),
    ('Healthcare & Life Sciences', 'HEALTH'),
    ('Manufacturing & Engineering', 'MFG')
ON CONFLICT (industry_name) DO NOTHING;

INSERT INTO master_data.job_role (industry_id, role_name, role_code)
SELECT i.id, 'Database Engineer', 'DB_ENG'
FROM master_data.industry i WHERE i.industry_name = 'Information Technology & Software'
ON CONFLICT DO NOTHING;

INSERT INTO master_data.job_role (industry_id, role_name, role_code)
SELECT i.id, 'Full Stack Developer', 'FSD_ENG'
FROM master_data.industry i WHERE i.industry_name = 'Information Technology & Software'
ON CONFLICT DO NOTHING;

INSERT INTO master_data.skill (skill_name, normalized_name)
VALUES 
    ('PostgreSQL', 'postgresql'),
    ('Python', 'python'),
    ('SQL Optimization', 'sql optimization'),
    ('Docker', 'docker'),
    ('Node.js', 'nodejs'),
    ('Data Modeling', 'data modeling')
ON CONFLICT (skill_name) DO NOTHING;

INSERT INTO master_data.proficiency_level (code, display_name, sort_order)
VALUES 
    ('beginner', 'Beginner', 1),
    ('intermediate', 'Intermediate', 2),
    ('advanced', 'Advanced', 3),
    ('expert', 'Expert', 4)
ON CONFLICT (code) DO NOTHING;

INSERT INTO master_data.job_requirement_status (code, display_name, sort_order)
VALUES 
    ('draft', 'Draft', 1),
    ('published', 'Published', 2),
    ('paused', 'Paused', 3),
    ('closed', 'Closed', 4)
ON CONFLICT (code) DO NOTHING;

INSERT INTO master_data.application_status (code, display_name, sort_order)
VALUES 
    ('submitted', 'Submitted', 1),
    ('screening', 'Screening', 2),
    ('shortlisted', 'Shortlisted', 3),
    ('interview', 'Interviewing', 4),
    ('offered', 'Offer Extended', 5),
    ('joined', 'Joined', 6),
    ('rejected', 'Rejected', 7),
    ('withdrawn', 'Withdrawn', 8)
ON CONFLICT (code) DO NOTHING;

INSERT INTO master_data.interview_status (code, display_name, sort_order)
VALUES 
    ('scheduled', 'Scheduled', 1),
    ('completed', 'Completed', 2),
    ('cancelled', 'Cancelled', 3),
    ('rescheduled', 'Rescheduled', 4)
ON CONFLICT (code) DO NOTHING;

INSERT INTO master_data.interview_type (code, display_name, sort_order)
VALUES 
    ('technical', 'Technical Assessment', 1),
    ('hr', 'HR Culture Fit', 2),
    ('managerial', 'Hiring Manager Discussion', 3),
    ('panel', 'Panel Defense', 4)
ON CONFLICT (code) DO NOTHING;

INSERT INTO master_data.offer_status (code, display_name, sort_order)
VALUES 
    ('pending', 'Pending Response', 1),
    ('accepted', 'Accepted', 2),
    ('declined', 'Declined', 3),
    ('revoked', 'Revoked', 4)
ON CONFLICT (code) DO NOTHING;

INSERT INTO master_data.question_type (code, display_name, sort_order)
VALUES 
    ('text', 'Text Response', 1),
    ('single_choice', 'Single Choice', 2),
    ('multiple_choice', 'Multiple Choice', 3),
    ('boolean', 'Yes / No', 4)
ON CONFLICT (code) DO NOTHING;

INSERT INTO master_data.referral_status (code, display_name, sort_order)
VALUES 
    ('pending', 'Pending Review', 1),
    ('qualified', 'Candidate Qualified', 2),
    ('hired', 'Candidate Hired', 3),
    ('reward_paid', 'Reward Disbursed', 4)
ON CONFLICT (code) DO NOTHING;

-- ----------------------------------------------------------------------------
-- 5. PROFILE: TEMPLATES, CANDIDATES, CERTIFICATIONS & PREFERENCES
-- ----------------------------------------------------------------------------
INSERT INTO profile.resume_template (template_name, layout_format, is_active)
VALUES 
    ('Modern Tech Clean', 'modern_two_column', true),
    ('Executive Traditional', 'classic_single_column', true)
ON CONFLICT (template_name) DO NOTHING;

INSERT INTO profile.candidate_profile 
    (user_id, full_name, date_of_birth, headline, summary, country_id, city_id, years_experience, profile_completion_percentage, profile_visibility_code, content_language_id)
SELECT 
    1001,
    'Aarav Sharma', 
    '1996-05-15', 
    'Senior PostgreSQL Database Architect',
    'Specialist in high-throughput transactional databases and analytical pipelines.',
    c.id,
    ct.id,
    6.5,
    95.00,
    'public',
    l.id
FROM master_data.country c
CROSS JOIN master_data.city ct
CROSS JOIN master_data.language l
WHERE c.iso_code_2 = 'IN'
  AND ct.name = 'Bengaluru'
  AND l.code = 'en'
AND NOT EXISTS (SELECT 1 FROM profile.candidate_profile WHERE full_name = 'Aarav Sharma');

INSERT INTO profile.candidate_contact
    (candidate_profile_id, email, phone, phone_country_code, city_id, country_id, address_line, postal_code, contact_visibility_code)
SELECT 
    cp.id,
    'aarav.sharma@example.com',
    '+919876543210',
    '+91',
    ct.id,
    c.id,
    '42 Tech Park Avenue, Koramangala',
    '560034',
    'recruiter_only'
FROM profile.candidate_profile cp
CROSS JOIN master_data.country c
CROSS JOIN master_data.city ct
WHERE cp.full_name = 'Aarav Sharma'
  AND c.iso_code_2 = 'IN'
  AND ct.name = 'Bengaluru'
ON CONFLICT (email) DO NOTHING;

INSERT INTO profile.candidate_education
    (candidate_profile_id, education_level_id, qualification_id, institution_name, qualification, field_of_study, start_date, end_date, grade_value, grade_scale, is_current)
SELECT 
    cp.id,
    el.id,
    q.id,
    'Indian Institute of Technology, Delhi',
    'Bachelor of Technology',
    'Computer Science and Engineering',
    '2014-08-01',
    '2018-05-30',
    8.90,
    '10_POINT_CGPA',
    false
FROM profile.candidate_profile cp
CROSS JOIN master_data.education_level el
LEFT JOIN master_data.qualification q ON q.qualification_code = 'BTECH'
WHERE cp.full_name = 'Aarav Sharma'
  AND el.level_name = 'Bachelor''s Degree'
  AND NOT EXISTS (SELECT 1 FROM profile.candidate_education WHERE candidate_profile_id = cp.id);

INSERT INTO profile.candidate_work_experience
    (candidate_profile_id, company_name, job_title, employment_type_id, start_date, end_date, is_current, description)
SELECT 
    cp.id,
    'Northbridge Workforce Systems',
    'Senior Database Developer',
    et.id,
    '2021-06-01',
    NULL,
    true,
    'Architected core database tier supporting 10M+ candidate records, tuned query execution plans and partitioned fact tables.'
FROM profile.candidate_profile cp
CROSS JOIN master_data.employment_type et
WHERE cp.full_name = 'Aarav Sharma'
  AND et.type_name = 'Full-time'
  AND NOT EXISTS (SELECT 1 FROM profile.candidate_work_experience WHERE candidate_profile_id = cp.id);

INSERT INTO profile.candidate_skill (candidate_profile_id, skill_id, proficiency_level_id, years_used)
SELECT cp.id, s.id, p.id, 6.0
FROM profile.candidate_profile cp
CROSS JOIN master_data.skill s
CROSS JOIN master_data.proficiency_level p
WHERE cp.full_name = 'Aarav Sharma'
  AND s.skill_name = 'PostgreSQL'
  AND p.code = 'expert'
ON CONFLICT (candidate_profile_id, skill_id) DO NOTHING;

INSERT INTO profile.candidate_language (candidate_profile_id, language_id, proficiency_level_id)
SELECT cp.id, l.id, p.id
FROM profile.candidate_profile cp
CROSS JOIN master_data.language l
CROSS JOIN master_data.proficiency_level p
WHERE cp.full_name = 'Aarav Sharma'
  AND l.code = 'en'
  AND p.code = 'expert'
ON CONFLICT (candidate_profile_id, language_id) DO NOTHING;

INSERT INTO profile.profile_project
    (candidate_profile_id, project_title, role_name, start_date, end_date, outcome_summary, project_url)
SELECT 
    cp.id,
    'Talentra High-Scale Database Engine',
    'Lead Database Architect',
    '2024-01-01',
    '2024-06-30',
    'Modeled star schema and relational OLTP engine handling 100M rows with sub-100ms p95 latencies.',
    'https://github.com/crazyluhsnap/talentra-database-design'
FROM profile.candidate_profile cp
WHERE cp.full_name = 'Aarav Sharma'
  AND NOT EXISTS (SELECT 1 FROM profile.profile_project WHERE candidate_profile_id = cp.id);

INSERT INTO profile.resume_document
    (candidate_profile_id, resume_template_id, version_number, title, file_uri, storage_key, mime_type, file_size_bytes, resume_body, is_primary)
SELECT 
    cp.id,
    rt.id,
    1,
    'Aarav_Sharma_Resume_2026.pdf',
    's3://talentra-resumes/candidates/aarav_sharma_v1.pdf',
    'candidates/1001/resumes/v1.pdf',
    'application/pdf',
    245760,
    'Aarav Sharma - Lead Database Architect with extensive experience in PostgreSQL relational modeling, indexing strategies, and high-concurrency systems.',
    true
FROM profile.candidate_profile cp
CROSS JOIN profile.resume_template rt
WHERE cp.full_name = 'Aarav Sharma'
  AND rt.template_name = 'Modern Tech Clean'
ON CONFLICT (candidate_profile_id, version_number) DO NOTHING;

INSERT INTO profile.candidate_certification
    (candidate_profile_id, certification_name, issuer, credential_id, credential_url, issue_date, expiry_date)
SELECT 
    cp.id,
    'PostgreSQL Certified Professional DBA',
    'PostgreSQL Professional Association',
    'PG-DBA-99214',
    'https://postgrespro.com/cert/99214',
    '2022-04-10',
    '2027-04-10'
FROM profile.candidate_profile cp
WHERE cp.full_name = 'Aarav Sharma'
AND NOT EXISTS (SELECT 1 FROM profile.candidate_certification WHERE candidate_profile_id = cp.id);

INSERT INTO profile.candidate_preference
    (candidate_profile_id, job_role_id, location_id, employment_type_id, work_type_id, minimum_salary, salary_currency)
SELECT 
    cp.id,
    jr.id,
    loc.id,
    et.id,
    wt.id,
    3500000.00,
    'INR'
FROM profile.candidate_profile cp
CROSS JOIN master_data.job_role jr
CROSS JOIN master_data.location loc
CROSS JOIN master_data.employment_type et
CROSS JOIN master_data.work_type wt
WHERE cp.full_name = 'Aarav Sharma'
  AND jr.role_name = 'Database Engineer'
  AND loc.location_name = 'EcoWorld Tech Park - Tower 4'
  AND et.type_name = 'Full-time'
  AND wt.type_name = 'Hybrid'
AND NOT EXISTS (SELECT 1 FROM profile.candidate_preference WHERE candidate_profile_id = cp.id);

INSERT INTO profile.candidate_bookmark (candidate_profile_id, notes)
SELECT cp.id, 'Top candidate for database lead role.'
FROM profile.candidate_profile cp
WHERE cp.full_name = 'Aarav Sharma'
  AND NOT EXISTS (SELECT 1 FROM profile.candidate_bookmark WHERE candidate_profile_id = cp.id);

INSERT INTO profile.candidate_referral (candidate_profile_id, referral_code, referral_status_id, reward_amount, reward_currency)
SELECT cp.id, 'REF-POSTGRES-2026', rs.id, 50000.00, 'INR'
FROM profile.candidate_profile cp
CROSS JOIN master_data.referral_status rs
WHERE cp.full_name = 'Aarav Sharma'
  AND rs.code = 'qualified'
  AND NOT EXISTS (SELECT 1 FROM profile.candidate_referral WHERE candidate_profile_id = cp.id);

-- ----------------------------------------------------------------------------
-- 6. RECRUITMENT: JOB REQUIREMENT, QUESTIONNAIRE & OPTIONS
-- ----------------------------------------------------------------------------
INSERT INTO recruitment.job_requirement (
    job_title,
    job_description,
    employment_type_id,
    work_type_id,
    industry_id,
    job_role_id,
    location_id,
    city_id,
    country_id,
    positions_count,
    min_experience_years,
    max_experience_years,
    min_salary,
    max_salary,
    currency_code,
    status_id,
    is_open_to_consultants,
    published_at
)
SELECT 
    'Principal PostgreSQL Database Architect',
    'Lead the design, benchmarking, and scaling of our enterprise workforce database supporting 10M+ candidates and 100M+ applications.',
    et.id,
    wt.id,
    ind.id,
    jr.id,
    loc.id,
    ct.id,
    c.id,
    2,
    5.0,
    10.0,
    3000000.00,
    4500000.00,
    'INR',
    js.id,
    true,
    CURRENT_TIMESTAMP
FROM master_data.employment_type et
CROSS JOIN master_data.work_type wt
CROSS JOIN master_data.industry ind
CROSS JOIN master_data.job_role jr
CROSS JOIN master_data.location loc
CROSS JOIN master_data.city ct
CROSS JOIN master_data.country c
CROSS JOIN master_data.job_requirement_status js
WHERE et.type_name = 'Full-time'
  AND wt.type_name = 'Hybrid'
  AND ind.industry_name = 'Information Technology & Software'
  AND jr.role_name = 'Database Engineer'
  AND loc.location_name = 'EcoWorld Tech Park - Tower 4'
  AND ct.name = 'Bengaluru'
  AND c.iso_code_2 = 'IN'
  AND js.code = 'published'
  AND NOT EXISTS (SELECT 1 FROM recruitment.job_requirement WHERE job_title = 'Principal PostgreSQL Database Architect');

INSERT INTO recruitment.job_questionnaire (job_requirement_id, title, instructions, version_number, is_mandatory)
SELECT jr.id, 'Database Architecture Screening Questionnaire', 'Please provide honest technical answers.', 1, true
FROM recruitment.job_requirement jr
WHERE jr.job_title = 'Principal PostgreSQL Database Architect'
ON CONFLICT (job_requirement_id, version_number) DO NOTHING;

INSERT INTO recruitment.job_question (job_questionnaire_id, question_text, question_type_id, is_required, sort_order)
SELECT jq.id, 'How many years of production PostgreSQL query optimization experience do you have?', qt.id, true, 1
FROM recruitment.job_questionnaire jq
CROSS JOIN master_data.question_type qt
WHERE jq.title = 'Database Architecture Screening Questionnaire'
  AND qt.code = 'single_choice'
  AND NOT EXISTS (SELECT 1 FROM recruitment.job_question WHERE job_questionnaire_id = jq.id);

INSERT INTO recruitment.job_question_option (job_question_id, option_text, sort_order)
SELECT q.id, '5+ years with large-scale relational systems', 1
FROM recruitment.job_question q
WHERE q.question_text LIKE 'How many years of production PostgreSQL%'
  AND NOT EXISTS (SELECT 1 FROM recruitment.job_question_option WHERE job_question_id = q.id);

-- ----------------------------------------------------------------------------
-- 7. RECRUITMENT: APPLICATION, MULTI-PANEL INTERVIEWS & SEARCH HISTORY
-- ----------------------------------------------------------------------------
INSERT INTO recruitment.job_application (
    job_requirement_id,
    candidate_profile_id,
    selected_resume_document_id,
    status_id,
    source_code,
    cover_letter
)
SELECT 
    jr.id,
    cp.id,
    rd.id,
    st.id,
    'direct',
    'I have over 6 years of deep PostgreSQL performance tuning and data modeling experience. Excited to contribute to Talentra.'
FROM recruitment.job_requirement jr
CROSS JOIN profile.candidate_profile cp
LEFT JOIN profile.resume_document rd ON rd.candidate_profile_id = cp.id AND rd.is_primary = true
CROSS JOIN master_data.application_status st
WHERE jr.job_title = 'Principal PostgreSQL Database Architect'
  AND cp.full_name = 'Aarav Sharma'
  AND st.code = 'interview'
ON CONFLICT (job_requirement_id, candidate_profile_id) DO NOTHING;

INSERT INTO recruitment.candidate_question_answer (job_application_id, job_question_id, selected_option_id, answer_text)
SELECT ja.id, jq.id, opt.id, '5+ years with large-scale relational systems'
FROM recruitment.job_application ja
JOIN recruitment.job_requirement jr ON jr.id = ja.job_requirement_id
JOIN recruitment.job_questionnaire qn ON qn.job_requirement_id = jr.id
JOIN recruitment.job_question jq ON jq.job_questionnaire_id = qn.id
JOIN recruitment.job_question_option opt ON opt.job_question_id = jq.id
WHERE jr.job_title = 'Principal PostgreSQL Database Architect'
ON CONFLICT (job_application_id, job_question_id) DO NOTHING;

INSERT INTO recruitment.job_interview (
    job_application_id,
    interview_type_id,
    status_id,
    interview_round,
    mode_code,
    meeting_reference,
    interviewer_name,
    scheduled_at
)
SELECT 
    ja.id,
    it.id,
    ist.id,
    1,
    'video',
    'https://meet.google.com/xyz-post-gres',
    'Dr. Aris Thorne',
    CURRENT_TIMESTAMP + INTERVAL '2 days'
FROM recruitment.job_application ja
JOIN recruitment.job_requirement jr ON jr.id = ja.job_requirement_id
CROSS JOIN master_data.interview_type it
CROSS JOIN master_data.interview_status ist
WHERE jr.job_title = 'Principal PostgreSQL Database Architect'
  AND it.code = 'panel'
  AND ist.code = 'scheduled'
  AND NOT EXISTS (SELECT 1 FROM recruitment.job_interview WHERE job_application_id = ja.id);

INSERT INTO recruitment.interview_feedback (
    job_interview_id,
    interviewer_name,
    technical_rating,
    communication_rating,
    problem_solving_rating,
    overall_rating,
    recommendation_code,
    feedback_text
)
SELECT 
    ji.id,
    'Dr. Aris Thorne',
    5,
    5,
    5,
    5.0,
    'strong_hire',
    'Candidate demonstrates thorough understanding of surrogate keys, database locking, and B-Tree mechanics.'
FROM recruitment.job_interview ji
JOIN recruitment.job_application ja ON ja.id = ji.job_application_id
JOIN recruitment.job_requirement jr ON jr.id = ja.job_requirement_id
WHERE jr.job_title = 'Principal PostgreSQL Database Architect'
AND NOT EXISTS (SELECT 1 FROM recruitment.interview_feedback WHERE job_interview_id = ji.id);

INSERT INTO recruitment.application_status_history (job_application_id, from_status_id, to_status_id, reason_code, notes)
SELECT 
    ja.id,
    s_from.id,
    s_to.id,
    'advanced_after_tech_screening',
    'Candidate advanced to Panel Defense stage after stellar technical screening.'
FROM recruitment.job_application ja
CROSS JOIN master_data.application_status s_from
CROSS JOIN master_data.application_status s_to
WHERE s_from.code = 'screening'
  AND s_to.code = 'interview'
  AND NOT EXISTS (SELECT 1 FROM recruitment.application_status_history WHERE job_application_id = ja.id);

INSERT INTO recruitment.candidate_job_search_history (candidate_profile_id, search_keywords, results_count)
SELECT cp.id, 'PostgreSQL Database Architect', 12
FROM profile.candidate_profile cp
WHERE cp.full_name = 'Aarav Sharma'
  AND NOT EXISTS (SELECT 1 FROM recruitment.candidate_job_search_history WHERE candidate_profile_id = cp.id);

COMMIT;
