--
-- PostgreSQL database dump
--

\restrict Y8urL6oMe4O1lkcitzdctTsx485iOzkTztgbMqrRJfMcTaJgdNPqUHTTfrYgTLp

-- Dumped from database version 18.6
-- Dumped by pg_dump version 18.6

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: master_data; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA master_data;


--
-- Name: profile; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA profile;


--
-- Name: recruitment; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA recruitment;


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: education_level; Type: TABLE; Schema: master_data; Owner: -
--

CREATE TABLE master_data.education_level (
    education_level_id bigint NOT NULL,
    level_name character varying(100) NOT NULL
);


--
-- Name: education_level_education_level_id_seq; Type: SEQUENCE; Schema: master_data; Owner: -
--

ALTER TABLE master_data.education_level ALTER COLUMN education_level_id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME master_data.education_level_education_level_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: employment_type; Type: TABLE; Schema: master_data; Owner: -
--

CREATE TABLE master_data.employment_type (
    employment_type_id bigint NOT NULL,
    type_name character varying(50) NOT NULL
);


--
-- Name: employment_type_employment_type_id_seq; Type: SEQUENCE; Schema: master_data; Owner: -
--

ALTER TABLE master_data.employment_type ALTER COLUMN employment_type_id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME master_data.employment_type_employment_type_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: language; Type: TABLE; Schema: master_data; Owner: -
--

CREATE TABLE master_data.language (
    language_id bigint NOT NULL,
    language_name character varying(100) NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


--
-- Name: language_language_id_seq; Type: SEQUENCE; Schema: master_data; Owner: -
--

ALTER TABLE master_data.language ALTER COLUMN language_id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME master_data.language_language_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: skill; Type: TABLE; Schema: master_data; Owner: -
--

CREATE TABLE master_data.skill (
    skill_id bigint NOT NULL,
    skill_name character varying(100) NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


--
-- Name: skill_skill_id_seq; Type: SEQUENCE; Schema: master_data; Owner: -
--

ALTER TABLE master_data.skill ALTER COLUMN skill_id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME master_data.skill_skill_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: candidate_contact; Type: TABLE; Schema: profile; Owner: -
--

CREATE TABLE profile.candidate_contact (
    contact_id bigint NOT NULL,
    candidate_id bigint NOT NULL,
    email character varying(320),
    phone character varying(30),
    city character varying(100),
    country character varying(100),
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


--
-- Name: candidate_contact_contact_id_seq; Type: SEQUENCE; Schema: profile; Owner: -
--

ALTER TABLE profile.candidate_contact ALTER COLUMN contact_id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME profile.candidate_contact_contact_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: candidate_education; Type: TABLE; Schema: profile; Owner: -
--

CREATE TABLE profile.candidate_education (
    education_id bigint NOT NULL,
    candidate_id bigint NOT NULL,
    education_level_id bigint,
    institution_name character varying(200) NOT NULL,
    qualification character varying(200),
    field_of_study character varying(200),
    start_date date,
    end_date date,
    grade character varying(50),
    CONSTRAINT chk_education_dates CHECK (((end_date IS NULL) OR (start_date IS NULL) OR (end_date >= start_date)))
);


--
-- Name: candidate_education_education_id_seq; Type: SEQUENCE; Schema: profile; Owner: -
--

ALTER TABLE profile.candidate_education ALTER COLUMN education_id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME profile.candidate_education_education_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: candidate_language; Type: TABLE; Schema: profile; Owner: -
--

CREATE TABLE profile.candidate_language (
    candidate_id bigint NOT NULL,
    language_id bigint NOT NULL,
    proficiency_level character varying(30)
);


--
-- Name: candidate_profile; Type: TABLE; Schema: profile; Owner: -
--

CREATE TABLE profile.candidate_profile (
    candidate_id bigint NOT NULL,
    first_name character varying(100) NOT NULL,
    last_name character varying(100),
    date_of_birth date,
    headline character varying(250),
    summary text,
    years_experience numeric(4,1),
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT candidate_profile_years_experience_check CHECK ((years_experience >= (0)::numeric))
);


--
-- Name: candidate_profile_candidate_id_seq; Type: SEQUENCE; Schema: profile; Owner: -
--

ALTER TABLE profile.candidate_profile ALTER COLUMN candidate_id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME profile.candidate_profile_candidate_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: candidate_skill; Type: TABLE; Schema: profile; Owner: -
--

CREATE TABLE profile.candidate_skill (
    candidate_id bigint NOT NULL,
    skill_id bigint NOT NULL,
    proficiency_level character varying(30),
    years_used numeric(4,1),
    CONSTRAINT candidate_skill_years_used_check CHECK ((years_used >= (0)::numeric))
);


--
-- Name: candidate_work_experience; Type: TABLE; Schema: profile; Owner: -
--

CREATE TABLE profile.candidate_work_experience (
    experience_id bigint NOT NULL,
    candidate_id bigint NOT NULL,
    company_name character varying(200) NOT NULL,
    job_title character varying(200) NOT NULL,
    employment_type_id bigint,
    start_date date,
    end_date date,
    description text,
    CONSTRAINT chk_experience_dates CHECK (((end_date IS NULL) OR (start_date IS NULL) OR (end_date >= start_date)))
);


--
-- Name: candidate_work_experience_experience_id_seq; Type: SEQUENCE; Schema: profile; Owner: -
--

ALTER TABLE profile.candidate_work_experience ALTER COLUMN experience_id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME profile.candidate_work_experience_experience_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: application_status_history; Type: TABLE; Schema: recruitment; Owner: -
--

CREATE TABLE recruitment.application_status_history (
    history_id bigint NOT NULL,
    application_id bigint NOT NULL,
    old_status character varying(30),
    new_status character varying(30) NOT NULL,
    changed_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    notes text
);


--
-- Name: application_status_history_history_id_seq; Type: SEQUENCE; Schema: recruitment; Owner: -
--

ALTER TABLE recruitment.application_status_history ALTER COLUMN history_id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME recruitment.application_status_history_history_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: job_application; Type: TABLE; Schema: recruitment; Owner: -
--

CREATE TABLE recruitment.job_application (
    application_id bigint NOT NULL,
    job_id bigint NOT NULL,
    candidate_id bigint NOT NULL,
    applied_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    status character varying(30) DEFAULT 'submitted'::character varying NOT NULL,
    cover_letter text,
    CONSTRAINT job_application_status_check CHECK (((status)::text = ANY ((ARRAY['submitted'::character varying, 'screening'::character varying, 'shortlisted'::character varying, 'interview'::character varying, 'offered'::character varying, 'hired'::character varying, 'rejected'::character varying, 'withdrawn'::character varying])::text[])))
);


--
-- Name: job_application_application_id_seq; Type: SEQUENCE; Schema: recruitment; Owner: -
--

ALTER TABLE recruitment.job_application ALTER COLUMN application_id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME recruitment.job_application_application_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: job_interview; Type: TABLE; Schema: recruitment; Owner: -
--

CREATE TABLE recruitment.job_interview (
    interview_id bigint NOT NULL,
    application_id bigint NOT NULL,
    scheduled_at timestamp with time zone,
    interview_type character varying(50),
    status character varying(30) DEFAULT 'scheduled'::character varying NOT NULL,
    feedback text,
    CONSTRAINT job_interview_status_check CHECK (((status)::text = ANY ((ARRAY['scheduled'::character varying, 'completed'::character varying, 'cancelled'::character varying, 'rescheduled'::character varying])::text[])))
);


--
-- Name: job_interview_interview_id_seq; Type: SEQUENCE; Schema: recruitment; Owner: -
--

ALTER TABLE recruitment.job_interview ALTER COLUMN interview_id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME recruitment.job_interview_interview_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: job_offer; Type: TABLE; Schema: recruitment; Owner: -
--

CREATE TABLE recruitment.job_offer (
    offer_id bigint NOT NULL,
    application_id bigint NOT NULL,
    offered_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    salary_amount numeric(12,2),
    salary_currency character(3),
    status character varying(30) DEFAULT 'pending'::character varying NOT NULL,
    expires_at timestamp with time zone,
    CONSTRAINT job_offer_salary_amount_check CHECK ((salary_amount >= (0)::numeric)),
    CONSTRAINT job_offer_status_check CHECK (((status)::text = ANY ((ARRAY['pending'::character varying, 'accepted'::character varying, 'declined'::character varying, 'revoked'::character varying])::text[])))
);


--
-- Name: job_offer_offer_id_seq; Type: SEQUENCE; Schema: recruitment; Owner: -
--

ALTER TABLE recruitment.job_offer ALTER COLUMN offer_id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME recruitment.job_offer_offer_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: job_requirement; Type: TABLE; Schema: recruitment; Owner: -
--

CREATE TABLE recruitment.job_requirement (
    job_id bigint NOT NULL,
    job_title character varying(200) NOT NULL,
    job_description text NOT NULL,
    employment_type_id bigint,
    location character varying(200),
    min_experience_years numeric(4,1),
    max_experience_years numeric(4,1),
    status character varying(30) DEFAULT 'draft'::character varying NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT chk_job_experience_range CHECK (((max_experience_years IS NULL) OR (min_experience_years IS NULL) OR (max_experience_years >= min_experience_years))),
    CONSTRAINT job_requirement_max_experience_years_check CHECK ((max_experience_years >= (0)::numeric)),
    CONSTRAINT job_requirement_min_experience_years_check CHECK ((min_experience_years >= (0)::numeric)),
    CONSTRAINT job_requirement_status_check CHECK (((status)::text = ANY ((ARRAY['draft'::character varying, 'published'::character varying, 'paused'::character varying, 'closed'::character varying])::text[])))
);


--
-- Name: job_requirement_job_id_seq; Type: SEQUENCE; Schema: recruitment; Owner: -
--

ALTER TABLE recruitment.job_requirement ALTER COLUMN job_id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME recruitment.job_requirement_job_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: job_shortlist; Type: TABLE; Schema: recruitment; Owner: -
--

CREATE TABLE recruitment.job_shortlist (
    job_id bigint NOT NULL,
    candidate_id bigint NOT NULL,
    shortlisted_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    notes text
);


--
-- Name: education_level education_level_pkey; Type: CONSTRAINT; Schema: master_data; Owner: -
--

ALTER TABLE ONLY master_data.education_level
    ADD CONSTRAINT education_level_pkey PRIMARY KEY (education_level_id);


--
-- Name: employment_type employment_type_pkey; Type: CONSTRAINT; Schema: master_data; Owner: -
--

ALTER TABLE ONLY master_data.employment_type
    ADD CONSTRAINT employment_type_pkey PRIMARY KEY (employment_type_id);


--
-- Name: language language_pkey; Type: CONSTRAINT; Schema: master_data; Owner: -
--

ALTER TABLE ONLY master_data.language
    ADD CONSTRAINT language_pkey PRIMARY KEY (language_id);


--
-- Name: skill skill_pkey; Type: CONSTRAINT; Schema: master_data; Owner: -
--

ALTER TABLE ONLY master_data.skill
    ADD CONSTRAINT skill_pkey PRIMARY KEY (skill_id);


--
-- Name: education_level uq_education_level_name; Type: CONSTRAINT; Schema: master_data; Owner: -
--

ALTER TABLE ONLY master_data.education_level
    ADD CONSTRAINT uq_education_level_name UNIQUE (level_name);


--
-- Name: employment_type uq_employment_type_name; Type: CONSTRAINT; Schema: master_data; Owner: -
--

ALTER TABLE ONLY master_data.employment_type
    ADD CONSTRAINT uq_employment_type_name UNIQUE (type_name);


--
-- Name: language uq_language_name; Type: CONSTRAINT; Schema: master_data; Owner: -
--

ALTER TABLE ONLY master_data.language
    ADD CONSTRAINT uq_language_name UNIQUE (language_name);


--
-- Name: skill uq_skill_name; Type: CONSTRAINT; Schema: master_data; Owner: -
--

ALTER TABLE ONLY master_data.skill
    ADD CONSTRAINT uq_skill_name UNIQUE (skill_name);


--
-- Name: candidate_contact candidate_contact_pkey; Type: CONSTRAINT; Schema: profile; Owner: -
--

ALTER TABLE ONLY profile.candidate_contact
    ADD CONSTRAINT candidate_contact_pkey PRIMARY KEY (contact_id);


--
-- Name: candidate_education candidate_education_pkey; Type: CONSTRAINT; Schema: profile; Owner: -
--

ALTER TABLE ONLY profile.candidate_education
    ADD CONSTRAINT candidate_education_pkey PRIMARY KEY (education_id);


--
-- Name: candidate_language candidate_language_pkey; Type: CONSTRAINT; Schema: profile; Owner: -
--

ALTER TABLE ONLY profile.candidate_language
    ADD CONSTRAINT candidate_language_pkey PRIMARY KEY (candidate_id, language_id);


--
-- Name: candidate_profile candidate_profile_pkey; Type: CONSTRAINT; Schema: profile; Owner: -
--

ALTER TABLE ONLY profile.candidate_profile
    ADD CONSTRAINT candidate_profile_pkey PRIMARY KEY (candidate_id);


--
-- Name: candidate_skill candidate_skill_pkey; Type: CONSTRAINT; Schema: profile; Owner: -
--

ALTER TABLE ONLY profile.candidate_skill
    ADD CONSTRAINT candidate_skill_pkey PRIMARY KEY (candidate_id, skill_id);


--
-- Name: candidate_work_experience candidate_work_experience_pkey; Type: CONSTRAINT; Schema: profile; Owner: -
--

ALTER TABLE ONLY profile.candidate_work_experience
    ADD CONSTRAINT candidate_work_experience_pkey PRIMARY KEY (experience_id);


--
-- Name: candidate_contact uq_candidate_contact_email; Type: CONSTRAINT; Schema: profile; Owner: -
--

ALTER TABLE ONLY profile.candidate_contact
    ADD CONSTRAINT uq_candidate_contact_email UNIQUE (email);


--
-- Name: application_status_history application_status_history_pkey; Type: CONSTRAINT; Schema: recruitment; Owner: -
--

ALTER TABLE ONLY recruitment.application_status_history
    ADD CONSTRAINT application_status_history_pkey PRIMARY KEY (history_id);


--
-- Name: job_application job_application_pkey; Type: CONSTRAINT; Schema: recruitment; Owner: -
--

ALTER TABLE ONLY recruitment.job_application
    ADD CONSTRAINT job_application_pkey PRIMARY KEY (application_id);


--
-- Name: job_interview job_interview_pkey; Type: CONSTRAINT; Schema: recruitment; Owner: -
--

ALTER TABLE ONLY recruitment.job_interview
    ADD CONSTRAINT job_interview_pkey PRIMARY KEY (interview_id);


--
-- Name: job_offer job_offer_pkey; Type: CONSTRAINT; Schema: recruitment; Owner: -
--

ALTER TABLE ONLY recruitment.job_offer
    ADD CONSTRAINT job_offer_pkey PRIMARY KEY (offer_id);


--
-- Name: job_requirement job_requirement_pkey; Type: CONSTRAINT; Schema: recruitment; Owner: -
--

ALTER TABLE ONLY recruitment.job_requirement
    ADD CONSTRAINT job_requirement_pkey PRIMARY KEY (job_id);


--
-- Name: job_shortlist job_shortlist_pkey; Type: CONSTRAINT; Schema: recruitment; Owner: -
--

ALTER TABLE ONLY recruitment.job_shortlist
    ADD CONSTRAINT job_shortlist_pkey PRIMARY KEY (job_id, candidate_id);


--
-- Name: job_application uq_job_candidate_application; Type: CONSTRAINT; Schema: recruitment; Owner: -
--

ALTER TABLE ONLY recruitment.job_application
    ADD CONSTRAINT uq_job_candidate_application UNIQUE (job_id, candidate_id);


--
-- Name: idx_candidate_contact_candidate; Type: INDEX; Schema: profile; Owner: -
--

CREATE INDEX idx_candidate_contact_candidate ON profile.candidate_contact USING btree (candidate_id);


--
-- Name: idx_candidate_education_candidate; Type: INDEX; Schema: profile; Owner: -
--

CREATE INDEX idx_candidate_education_candidate ON profile.candidate_education USING btree (candidate_id);


--
-- Name: idx_candidate_language_language; Type: INDEX; Schema: profile; Owner: -
--

CREATE INDEX idx_candidate_language_language ON profile.candidate_language USING btree (language_id);


--
-- Name: idx_candidate_skill_skill; Type: INDEX; Schema: profile; Owner: -
--

CREATE INDEX idx_candidate_skill_skill ON profile.candidate_skill USING btree (skill_id);


--
-- Name: idx_candidate_work_candidate; Type: INDEX; Schema: profile; Owner: -
--

CREATE INDEX idx_candidate_work_candidate ON profile.candidate_work_experience USING btree (candidate_id);


--
-- Name: idx_application_history_application; Type: INDEX; Schema: recruitment; Owner: -
--

CREATE INDEX idx_application_history_application ON recruitment.application_status_history USING btree (application_id);


--
-- Name: idx_job_application_candidate; Type: INDEX; Schema: recruitment; Owner: -
--

CREATE INDEX idx_job_application_candidate ON recruitment.job_application USING btree (candidate_id);


--
-- Name: idx_job_application_job_status; Type: INDEX; Schema: recruitment; Owner: -
--

CREATE INDEX idx_job_application_job_status ON recruitment.job_application USING btree (job_id, status);


--
-- Name: idx_job_interview_application; Type: INDEX; Schema: recruitment; Owner: -
--

CREATE INDEX idx_job_interview_application ON recruitment.job_interview USING btree (application_id);


--
-- Name: idx_job_offer_application; Type: INDEX; Schema: recruitment; Owner: -
--

CREATE INDEX idx_job_offer_application ON recruitment.job_offer USING btree (application_id);


--
-- Name: idx_job_requirement_status; Type: INDEX; Schema: recruitment; Owner: -
--

CREATE INDEX idx_job_requirement_status ON recruitment.job_requirement USING btree (status);


--
-- Name: idx_job_shortlist_candidate; Type: INDEX; Schema: recruitment; Owner: -
--

CREATE INDEX idx_job_shortlist_candidate ON recruitment.job_shortlist USING btree (candidate_id);


--
-- Name: candidate_contact candidate_contact_candidate_id_fkey; Type: FK CONSTRAINT; Schema: profile; Owner: -
--

ALTER TABLE ONLY profile.candidate_contact
    ADD CONSTRAINT candidate_contact_candidate_id_fkey FOREIGN KEY (candidate_id) REFERENCES profile.candidate_profile(candidate_id) ON DELETE CASCADE;


--
-- Name: candidate_education candidate_education_candidate_id_fkey; Type: FK CONSTRAINT; Schema: profile; Owner: -
--

ALTER TABLE ONLY profile.candidate_education
    ADD CONSTRAINT candidate_education_candidate_id_fkey FOREIGN KEY (candidate_id) REFERENCES profile.candidate_profile(candidate_id) ON DELETE CASCADE;


--
-- Name: candidate_education candidate_education_education_level_id_fkey; Type: FK CONSTRAINT; Schema: profile; Owner: -
--

ALTER TABLE ONLY profile.candidate_education
    ADD CONSTRAINT candidate_education_education_level_id_fkey FOREIGN KEY (education_level_id) REFERENCES master_data.education_level(education_level_id);


--
-- Name: candidate_language candidate_language_candidate_id_fkey; Type: FK CONSTRAINT; Schema: profile; Owner: -
--

ALTER TABLE ONLY profile.candidate_language
    ADD CONSTRAINT candidate_language_candidate_id_fkey FOREIGN KEY (candidate_id) REFERENCES profile.candidate_profile(candidate_id) ON DELETE CASCADE;


--
-- Name: candidate_language candidate_language_language_id_fkey; Type: FK CONSTRAINT; Schema: profile; Owner: -
--

ALTER TABLE ONLY profile.candidate_language
    ADD CONSTRAINT candidate_language_language_id_fkey FOREIGN KEY (language_id) REFERENCES master_data.language(language_id);


--
-- Name: candidate_skill candidate_skill_candidate_id_fkey; Type: FK CONSTRAINT; Schema: profile; Owner: -
--

ALTER TABLE ONLY profile.candidate_skill
    ADD CONSTRAINT candidate_skill_candidate_id_fkey FOREIGN KEY (candidate_id) REFERENCES profile.candidate_profile(candidate_id) ON DELETE CASCADE;


--
-- Name: candidate_skill candidate_skill_skill_id_fkey; Type: FK CONSTRAINT; Schema: profile; Owner: -
--

ALTER TABLE ONLY profile.candidate_skill
    ADD CONSTRAINT candidate_skill_skill_id_fkey FOREIGN KEY (skill_id) REFERENCES master_data.skill(skill_id);


--
-- Name: candidate_work_experience candidate_work_experience_candidate_id_fkey; Type: FK CONSTRAINT; Schema: profile; Owner: -
--

ALTER TABLE ONLY profile.candidate_work_experience
    ADD CONSTRAINT candidate_work_experience_candidate_id_fkey FOREIGN KEY (candidate_id) REFERENCES profile.candidate_profile(candidate_id) ON DELETE CASCADE;


--
-- Name: candidate_work_experience candidate_work_experience_employment_type_id_fkey; Type: FK CONSTRAINT; Schema: profile; Owner: -
--

ALTER TABLE ONLY profile.candidate_work_experience
    ADD CONSTRAINT candidate_work_experience_employment_type_id_fkey FOREIGN KEY (employment_type_id) REFERENCES master_data.employment_type(employment_type_id);


--
-- Name: application_status_history application_status_history_application_id_fkey; Type: FK CONSTRAINT; Schema: recruitment; Owner: -
--

ALTER TABLE ONLY recruitment.application_status_history
    ADD CONSTRAINT application_status_history_application_id_fkey FOREIGN KEY (application_id) REFERENCES recruitment.job_application(application_id) ON DELETE CASCADE;


--
-- Name: job_application job_application_candidate_id_fkey; Type: FK CONSTRAINT; Schema: recruitment; Owner: -
--

ALTER TABLE ONLY recruitment.job_application
    ADD CONSTRAINT job_application_candidate_id_fkey FOREIGN KEY (candidate_id) REFERENCES profile.candidate_profile(candidate_id) ON DELETE CASCADE;


--
-- Name: job_application job_application_job_id_fkey; Type: FK CONSTRAINT; Schema: recruitment; Owner: -
--

ALTER TABLE ONLY recruitment.job_application
    ADD CONSTRAINT job_application_job_id_fkey FOREIGN KEY (job_id) REFERENCES recruitment.job_requirement(job_id) ON DELETE CASCADE;


--
-- Name: job_interview job_interview_application_id_fkey; Type: FK CONSTRAINT; Schema: recruitment; Owner: -
--

ALTER TABLE ONLY recruitment.job_interview
    ADD CONSTRAINT job_interview_application_id_fkey FOREIGN KEY (application_id) REFERENCES recruitment.job_application(application_id) ON DELETE CASCADE;


--
-- Name: job_offer job_offer_application_id_fkey; Type: FK CONSTRAINT; Schema: recruitment; Owner: -
--

ALTER TABLE ONLY recruitment.job_offer
    ADD CONSTRAINT job_offer_application_id_fkey FOREIGN KEY (application_id) REFERENCES recruitment.job_application(application_id) ON DELETE CASCADE;


--
-- Name: job_requirement job_requirement_employment_type_id_fkey; Type: FK CONSTRAINT; Schema: recruitment; Owner: -
--

ALTER TABLE ONLY recruitment.job_requirement
    ADD CONSTRAINT job_requirement_employment_type_id_fkey FOREIGN KEY (employment_type_id) REFERENCES master_data.employment_type(employment_type_id);


--
-- Name: job_shortlist job_shortlist_candidate_id_fkey; Type: FK CONSTRAINT; Schema: recruitment; Owner: -
--

ALTER TABLE ONLY recruitment.job_shortlist
    ADD CONSTRAINT job_shortlist_candidate_id_fkey FOREIGN KEY (candidate_id) REFERENCES profile.candidate_profile(candidate_id) ON DELETE CASCADE;


--
-- Name: job_shortlist job_shortlist_job_id_fkey; Type: FK CONSTRAINT; Schema: recruitment; Owner: -
--

ALTER TABLE ONLY recruitment.job_shortlist
    ADD CONSTRAINT job_shortlist_job_id_fkey FOREIGN KEY (job_id) REFERENCES recruitment.job_requirement(job_id) ON DELETE CASCADE;


--
-- PostgreSQL database dump complete
--

\unrestrict Y8urL6oMe4O1lkcitzdctTsx485iOzkTztgbMqrRJfMcTaJgdNPqUHTTfrYgTLp

