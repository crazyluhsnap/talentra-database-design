BEGIN;

INSERT INTO master_data.skill (skill_name)
VALUES ('PostgreSQL'), ('Python')
ON CONFLICT (skill_name) DO NOTHING;

INSERT INTO master_data.language (language_name)
VALUES ('English')
ON CONFLICT (language_name) DO NOTHING;

INSERT INTO master_data.education_level (level_name)
VALUES ('Bachelor''s Degree')
ON CONFLICT (level_name) DO NOTHING;

INSERT INTO master_data.employment_type (type_name)
VALUES ('Full-time')
ON CONFLICT (type_name) DO NOTHING;

INSERT INTO profile.candidate_profile
    (first_name, last_name, headline, years_experience)
SELECT 'Test', 'Candidate', 'Junior Database Developer', 1.0
WHERE NOT EXISTS (
    SELECT 1 FROM profile.candidate_profile
    WHERE first_name = 'Test'
      AND last_name = 'Candidate'
);

INSERT INTO profile.candidate_contact
    (candidate_id, email, city, country)
SELECT c.candidate_id, 'test.candidate@example.com', 'Delhi', 'India'
FROM profile.candidate_profile c
WHERE c.first_name = 'Test'
  AND c.last_name = 'Candidate'
  AND NOT EXISTS (
      SELECT 1 FROM profile.candidate_contact
      WHERE email = 'test.candidate@example.com'
  );

INSERT INTO profile.candidate_skill (candidate_id, skill_id)
SELECT c.candidate_id, s.skill_id
FROM profile.candidate_profile c
CROSS JOIN master_data.skill s
WHERE c.first_name = 'Test'
  AND c.last_name = 'Candidate'
  AND s.skill_name = 'PostgreSQL'
ON CONFLICT DO NOTHING;

INSERT INTO recruitment.job_requirement
    (job_title, job_description, employment_type_id, location, status)
SELECT
    'Junior Database Developer',
    'Test role for validating the Talentra database schema.',
    e.employment_type_id,
    'Delhi',
    'published'
FROM master_data.employment_type e
WHERE e.type_name = 'Full-time'
  AND NOT EXISTS (
      SELECT 1 FROM recruitment.job_requirement
      WHERE job_title = 'Junior Database Developer'
        AND job_description =
            'Test role for validating the Talentra database schema.'
  );

INSERT INTO recruitment.job_application
    (job_id, candidate_id, status, cover_letter)
SELECT j.job_id, c.candidate_id, 'submitted',
       'Test application for schema validation.'
FROM recruitment.job_requirement j
CROSS JOIN profile.candidate_profile c
WHERE j.job_title = 'Junior Database Developer'
  AND j.job_description =
      'Test role for validating the Talentra database schema.'
  AND c.first_name = 'Test'
  AND c.last_name = 'Candidate'
ON CONFLICT (job_id, candidate_id) DO NOTHING;

COMMIT;
