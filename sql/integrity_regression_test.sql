    \set ON_ERROR_STOP on

BEGIN;

-- All temporary test data is rolled back at the end.
DO $$
DECLARE
    v_candidate_id bigint;
    v_resume_id bigint;
    v_job_id bigint;
    v_application_id bigint;
    v_questionnaire_id bigint;
    v_question_id bigint;
    v_option_id bigint;
    v_status_id bigint;
    v_employment_type_id bigint;
    v_work_type_id bigint;
    v_country_id bigint;

    v_candidate_2 bigint;
    v_resume_2 bigint;
    v_job_2 bigint;
    v_questionnaire_2 bigint;
    v_question_2 bigint;
    v_option_2 bigint;
BEGIN
    SELECT id INTO STRICT v_candidate_id
    FROM profile.candidate_profile
    ORDER BY id LIMIT 1;

    SELECT id INTO STRICT v_resume_id
    FROM profile.resume_document
    WHERE candidate_profile_id = v_candidate_id
    ORDER BY id LIMIT 1;

    SELECT id INTO STRICT v_job_id
    FROM recruitment.job_requirement
    ORDER BY id LIMIT 1;

    SELECT id INTO STRICT v_application_id
    FROM recruitment.job_application
    WHERE candidate_profile_id = v_candidate_id
      AND job_requirement_id = v_job_id
    ORDER BY id LIMIT 1;

    SELECT id INTO STRICT v_questionnaire_id
    FROM recruitment.job_questionnaire
    WHERE job_requirement_id = v_job_id
    ORDER BY version_number LIMIT 1;

    SELECT id INTO STRICT v_question_id
    FROM recruitment.job_question
    WHERE job_questionnaire_id = v_questionnaire_id
    ORDER BY id LIMIT 1;

    SELECT id INTO STRICT v_option_id
    FROM recruitment.job_question_option
    WHERE job_question_id = v_question_id
    ORDER BY id LIMIT 1;

    SELECT status_id, employment_type_id, work_type_id, country_id
      INTO STRICT v_status_id, v_employment_type_id,
                  v_work_type_id, v_country_id
    FROM recruitment.job_requirement
    WHERE id = v_job_id;

    -- Create a second candidate and resume; let identity columns generate IDs.
    INSERT INTO profile.candidate_profile (full_name)
    VALUES ('Integrity Test Candidate')
    RETURNING id INTO v_candidate_2;

    INSERT INTO profile.resume_document
        (candidate_profile_id, title, file_uri)
    VALUES
        (v_candidate_2, 'Integrity Test Resume',
         'test://integrity-resume')
    RETURNING id INTO v_resume_2;

    -- Create a second job using valid lookup IDs.
    INSERT INTO recruitment.job_requirement
        (job_title, job_description, employment_type_id,
         work_type_id, country_id, status_id)
    VALUES
        ('Integrity Test Job', 'Temporary regression test job',
         v_employment_type_id, v_work_type_id, v_country_id, v_status_id)
    RETURNING id INTO v_job_2;

    INSERT INTO recruitment.job_questionnaire
        (job_requirement_id, title, version_number)
    VALUES
        (v_job_2, 'Integrity Test Questionnaire', 1)
    RETURNING id INTO v_questionnaire_2;

    INSERT INTO recruitment.job_question
        (job_questionnaire_id, question_text, question_type_id)
    SELECT v_questionnaire_2, 'Integrity test question', question_type_id
    
    FROM recruitment.job_question
    WHERE id = v_question_id
    RETURNING id INTO v_question_2;

    INSERT INTO recruitment.job_question_option
        (job_question_id, option_text)
    VALUES
        (v_question_2, 'Integrity test option')
    RETURNING id INTO v_option_2;

    -- TEST 1: Application cannot select another candidate's resume.
    BEGIN
        UPDATE recruitment.job_application
        SET selected_resume_document_id = v_resume_2
        WHERE id = v_application_id;

        RAISE EXCEPTION 'FAIL: cross-candidate resume was accepted';
    EXCEPTION WHEN foreign_key_violation THEN
        RAISE NOTICE 'PASS 1: cross-candidate resume rejected';
    END;

    -- TEST 2: An answer cannot select an option from another question.
    BEGIN
        UPDATE recruitment.candidate_question_answer
        SET selected_option_id = v_option_2
        WHERE job_application_id = v_application_id
          AND job_question_id = v_question_id;

        RAISE EXCEPTION 'FAIL: mismatched question option was accepted';
    EXCEPTION WHEN foreign_key_violation THEN
        RAISE NOTICE 'PASS 2: mismatched question option rejected';
    END;

    -- TEST 3: An application cannot answer a question for another job.
    BEGIN
        INSERT INTO recruitment.candidate_question_answer
            (job_application_id, job_question_id, answer_text)
        VALUES
            (v_application_id, v_question_2, 'Invalid cross-job answer');

        RAISE EXCEPTION 'FAIL: cross-job answer was accepted';
    EXCEPTION WHEN check_violation THEN
        RAISE NOTICE 'PASS 3: cross-job answer rejected';
    END;

    -- TEST 4: Changing the application's job must not invalidate answers.
    BEGIN
        UPDATE recruitment.job_application
        SET job_requirement_id = v_job_2
        WHERE id = v_application_id;

        RAISE EXCEPTION 'FAIL: application job change was accepted';
    EXCEPTION WHEN check_violation THEN
        RAISE NOTICE 'PASS 4: inconsistent application job change rejected';
    END;

    -- TEST 5: Moving an answered question to another job's questionnaire.
    BEGIN
        UPDATE recruitment.job_question
        SET job_questionnaire_id = v_questionnaire_2
        WHERE id = v_question_id;

        RAISE EXCEPTION 'FAIL: answered question move was accepted';
    EXCEPTION WHEN check_violation THEN
        RAISE NOTICE 'PASS 5: inconsistent question move rejected';
    END;

    -- TEST 6: Changing a questionnaire's job must not invalidate answers.
    BEGIN
        UPDATE recruitment.job_questionnaire
        SET job_requirement_id = v_job_2
        WHERE id = v_questionnaire_id;

        RAISE EXCEPTION 'FAIL: questionnaire job change was accepted';
    EXCEPTION WHEN check_violation THEN
        RAISE NOTICE 'PASS 6: inconsistent questionnaire job change rejected';
    END;

    -- TEST 7: A second version for the same job is valid.
    INSERT INTO recruitment.job_questionnaire
        (job_requirement_id, title, version_number)
    VALUES
        (v_job_id, 'Integrity Test Version 2', 2);

    RAISE NOTICE 'PASS 7: second questionnaire version accepted';

    -- TEST 8: A non-positive questionnaire version must be rejected.
    BEGIN
        INSERT INTO recruitment.job_questionnaire
            (job_requirement_id, title, version_number)
        VALUES
            (v_job_id, 'Invalid Questionnaire Version', 0);

        RAISE EXCEPTION 'FAIL: non-positive version was accepted';
    EXCEPTION WHEN check_violation THEN
        RAISE NOTICE 'PASS 8: non-positive questionnaire version rejected';
    END;

    RAISE NOTICE 'ALL 8 REGRESSION TESTS PASSED';
END;
$$;

ROLLBACK;
