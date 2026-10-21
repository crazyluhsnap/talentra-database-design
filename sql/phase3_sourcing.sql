-- ============================================================================
-- Talentra Enterprise Database Architecture
-- Phase 3 - Module A: Sourcing & Consultant Requests (sourcing)
-- PostgreSQL 16+
--
-- Conforming to: Talentra Phase 3 Improved Schemas Specification (Module A)
--
-- Entities:
-- 1. Recruitment Schema Extensions:
--    - Adds open_to_consultants flag to recruitment.job_requirement
--    - Attaches automatic openness logging trigger
-- 2. Lookups (Rule Group 3):
--    - sourcing_request_status
--    - decision_type
--    - decision_reason
--    - outreach_batch_status
--    - outreach_recipient_status
--    - outreach_channel
--    - shortlist_source_type
-- 3. Core Entities:
--    - sourcing_request
--    - sourcing_request_decision (Append-only)
--    - job_consultant_openness_event (Append-only)
--    - outreach_batch
--    - outreach_recipient
--    - sourcing_shortlist_entry
-- 4. Triggers, Auditing & Invariants:
--    - trg_sourcing_request_guard (Consultant role, job openness, block check)
--    - trg_sourcing_request_decision_sync (Status sync, closed_at, decider org check)
--    - trg_job_consultant_openness_logger (History logging trigger on job_requirement)
--    - trg_outreach_batch_recipient_count (Dynamic counter)
--    - trg_outreach_candidate_block_guard (Candidate blocking enforcement)
--    - trg_shortlist_source_type_guard (Provenance consistency)
-- 5. Full B-Tree & GIN Trigram Search Indexes
-- 6. Row-Level Security Policies & Operational Views
-- ============================================================================

\set ON_ERROR_STOP on

BEGIN;

CREATE SCHEMA IF NOT EXISTS sourcing;

-- ============================================================================
-- 1. RECRUITMENT SCHEMA EXTENSION (Prerequisite for Consultant Sourcing)
-- ============================================================================

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'recruitment' AND table_name = 'job_requirement' AND column_name = 'open_to_consultants'
    ) THEN
        ALTER TABLE recruitment.job_requirement 
        ADD COLUMN open_to_consultants boolean NOT NULL DEFAULT false;
    END IF;
END $$;

-- ============================================================================
-- 2. LOOKUP TABLES (Rule Group 3 Standard Pattern)
-- ============================================================================

CREATE TABLE sourcing.sourcing_request_status (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    code varchar(50) NOT NULL,
    name_key varchar(150) NOT NULL,
    is_active boolean NOT NULL DEFAULT true,
    sort_order integer NOT NULL,
    CONSTRAINT uq_sourcing_request_status_code UNIQUE (code),
    CONSTRAINT chk_sourcing_request_status_code CHECK (code ~ '^[a-z][a-z0-9_]*$')
);

CREATE TABLE sourcing.decision_type (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    code varchar(50) NOT NULL,
    name_key varchar(150) NOT NULL,
    is_active boolean NOT NULL DEFAULT true,
    sort_order integer NOT NULL,
    CONSTRAINT uq_decision_type_code UNIQUE (code),
    CONSTRAINT chk_decision_type_code CHECK (code ~ '^[a-z][a-z0-9_]*$')
);

CREATE TABLE sourcing.decision_reason (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    code varchar(50) NOT NULL,
    name_key varchar(150) NOT NULL,
    is_active boolean NOT NULL DEFAULT true,
    sort_order integer NOT NULL,
    CONSTRAINT uq_decision_reason_code UNIQUE (code),
    CONSTRAINT chk_decision_reason_code CHECK (code ~ '^[a-z][a-z0-9_]*$')
);

CREATE TABLE sourcing.outreach_batch_status (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    code varchar(50) NOT NULL,
    name_key varchar(150) NOT NULL,
    is_active boolean NOT NULL DEFAULT true,
    sort_order integer NOT NULL,
    CONSTRAINT uq_outreach_batch_status_code UNIQUE (code),
    CONSTRAINT chk_outreach_batch_status_code CHECK (code ~ '^[a-z][a-z0-9_]*$')
);

CREATE TABLE sourcing.outreach_recipient_status (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    code varchar(50) NOT NULL,
    name_key varchar(150) NOT NULL,
    is_active boolean NOT NULL DEFAULT true,
    sort_order integer NOT NULL,
    CONSTRAINT uq_outreach_recipient_status_code UNIQUE (code),
    CONSTRAINT chk_outreach_recipient_status_code CHECK (code ~ '^[a-z][a-z0-9_]*$')
);

CREATE TABLE sourcing.outreach_channel (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    code varchar(50) NOT NULL,
    name_key varchar(150) NOT NULL,
    is_active boolean NOT NULL DEFAULT true,
    sort_order integer NOT NULL,
    CONSTRAINT uq_outreach_channel_code UNIQUE (code),
    CONSTRAINT chk_outreach_channel_code CHECK (code ~ '^[a-z][a-z0-9_]*$')
);

CREATE TABLE sourcing.shortlist_source_type (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    code varchar(50) NOT NULL,
    name_key varchar(150) NOT NULL,
    is_active boolean NOT NULL DEFAULT true,
    sort_order integer NOT NULL,
    CONSTRAINT uq_shortlist_source_type_code UNIQUE (code),
    CONSTRAINT chk_shortlist_source_type_code CHECK (code ~ '^[a-z][a-z0-9_]*$')
);

-- ============================================================================
-- 3. CORE ENTITIES
-- ============================================================================

-- A consultant's request to source candidates for a job
CREATE TABLE sourcing.sourcing_request (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    job_requirement_id bigint NOT NULL REFERENCES recruitment.job_requirement(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    consultant_user_id bigint NOT NULL REFERENCES administration.user_account(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    sourcing_request_status_id bigint NOT NULL REFERENCES sourcing.sourcing_request_status(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    requested_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    note varchar(1000) NULL,
    closed_at timestamptz NULL,
    created_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by bigint NOT NULL REFERENCES administration.user_account(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    updated_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by bigint NOT NULL REFERENCES administration.user_account(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    CONSTRAINT uq_sourcing_request_id_job_requirement_id UNIQUE (id, job_requirement_id),
    CONSTRAINT ck_sourcing_request_closed CHECK (closed_at IS NULL OR closed_at >= requested_at)
);

CREATE UNIQUE INDEX uq_sourcing_request_active 
ON sourcing.sourcing_request(job_requirement_id, consultant_user_id) 
WHERE closed_at IS NULL;

CREATE INDEX idx_sourcing_request_consultant_user_id ON sourcing.sourcing_request(consultant_user_id);
CREATE INDEX idx_sourcing_request_job_requirement_id ON sourcing.sourcing_request(job_requirement_id);
CREATE INDEX idx_sourcing_request_status_id ON sourcing.sourcing_request(sourcing_request_status_id);

-- Employer acceptance or decline of a consultant request (Append-only)
CREATE TABLE sourcing.sourcing_request_decision (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    sourcing_request_id bigint NOT NULL REFERENCES sourcing.sourcing_request(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    decision_type_id bigint NOT NULL REFERENCES sourcing.decision_type(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    decided_by_user_id bigint NOT NULL REFERENCES administration.user_account(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    decided_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    decline_reason_id bigint NULL REFERENCES sourcing.decision_reason(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    reason_note varchar(500) NULL,
    created_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by bigint NOT NULL REFERENCES administration.user_account(id) ON UPDATE NO ACTION ON DELETE RESTRICT
);

CREATE INDEX idx_sourcing_request_decision_sourcing_request_id 
ON sourcing.sourcing_request_decision(sourcing_request_id, decided_at DESC);
CREATE INDEX idx_sourcing_request_decision_type_id ON sourcing.sourcing_request_decision(decision_type_id);
CREATE INDEX idx_sourcing_request_decision_decided_by ON sourcing.sourcing_request_decision(decided_by_user_id);
CREATE INDEX idx_sourcing_request_decision_decline_reason ON sourcing.sourcing_request_decision(decline_reason_id);

-- History of the open_to_consultants flag on a job (Append-only)
CREATE TABLE sourcing.job_consultant_openness_event (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    job_requirement_id bigint NOT NULL REFERENCES recruitment.job_requirement(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    is_open boolean NOT NULL,
    set_by_user_id bigint NOT NULL REFERENCES administration.user_account(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    set_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    reason_note varchar(300) NULL,
    created_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by bigint NOT NULL REFERENCES administration.user_account(id) ON UPDATE NO ACTION ON DELETE RESTRICT
);

CREATE INDEX idx_job_consultant_openness_event_job_requirement_id 
ON sourcing.job_consultant_openness_event(job_requirement_id, set_at DESC);
CREATE INDEX idx_job_consultant_openness_event_user ON sourcing.job_consultant_openness_event(set_by_user_id);

-- One bulk outreach campaign to candidates
CREATE TABLE sourcing.outreach_batch (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    job_requirement_id bigint NOT NULL REFERENCES recruitment.job_requirement(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    sourcing_request_id bigint NULL,
    organisation_id bigint NOT NULL REFERENCES organisation.organisation(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    initiated_by_user_id bigint NOT NULL REFERENCES administration.user_account(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    outreach_channel_id bigint NOT NULL REFERENCES sourcing.outreach_channel(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    outreach_batch_status_id bigint NOT NULL REFERENCES sourcing.outreach_batch_status(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    batch_name varchar(150) NULL,
    idempotency_key varchar(64) NOT NULL,
    scheduled_at timestamptz NULL,
    sent_at timestamptz NULL,
    recipient_count integer NOT NULL DEFAULT 0,
    created_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by bigint NOT NULL REFERENCES administration.user_account(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    updated_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by bigint NOT NULL REFERENCES administration.user_account(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    CONSTRAINT fk_outreach_batch_sourcing_request FOREIGN KEY (sourcing_request_id, job_requirement_id)
        REFERENCES sourcing.sourcing_request(id, job_requirement_id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    CONSTRAINT uq_outreach_batch_idempotency_key UNIQUE (organisation_id, idempotency_key),
    CONSTRAINT ck_outreach_batch_sent CHECK (sent_at IS NULL OR scheduled_at IS NULL OR sent_at >= scheduled_at),
    CONSTRAINT ck_outreach_batch_recipient_count CHECK (recipient_count >= 0)
);

CREATE INDEX idx_outreach_batch_job_requirement_id ON sourcing.outreach_batch(job_requirement_id);
CREATE INDEX idx_outreach_batch_sourcing_request_id ON sourcing.outreach_batch(sourcing_request_id);
CREATE INDEX idx_outreach_batch_organisation_id ON sourcing.outreach_batch(organisation_id);
CREATE INDEX idx_outreach_batch_initiated_by ON sourcing.outreach_batch(initiated_by_user_id);
CREATE INDEX idx_outreach_batch_channel_id ON sourcing.outreach_batch(outreach_channel_id);
CREATE INDEX idx_outreach_batch_status_id ON sourcing.outreach_batch(outreach_batch_status_id);

-- One candidate inside an outreach batch
CREATE TABLE sourcing.outreach_recipient (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    outreach_batch_id bigint NOT NULL REFERENCES sourcing.outreach_batch(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    candidate_profile_id bigint NOT NULL REFERENCES profile.candidate_profile(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    outreach_recipient_status_id bigint NOT NULL REFERENCES sourcing.outreach_recipient_status(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    notification_delivery_id bigint NULL,
    contacted_at timestamptz NULL,
    responded_at timestamptz NULL,
    created_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by bigint NOT NULL REFERENCES administration.user_account(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    updated_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by bigint NOT NULL REFERENCES administration.user_account(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    CONSTRAINT uq_outreach_recipient_batch_candidate UNIQUE (outreach_batch_id, candidate_profile_id),
    CONSTRAINT ck_outreach_recipient_responded CHECK (responded_at IS NULL OR (contacted_at IS NOT NULL AND responded_at >= contacted_at))
);

CREATE UNIQUE INDEX uq_outreach_recipient_notification_delivery_id 
ON sourcing.outreach_recipient(notification_delivery_id) 
WHERE notification_delivery_id IS NOT NULL;

CREATE INDEX idx_outreach_recipient_candidate_profile_id ON sourcing.outreach_recipient(candidate_profile_id);
CREATE INDEX idx_outreach_recipient_status_id ON sourcing.outreach_recipient(outreach_recipient_status_id);

-- Sourcing provenance for a candidate on the shared job shortlist
CREATE TABLE sourcing.sourcing_shortlist_entry (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    job_shortlist_candidate_id bigint NOT NULL REFERENCES recruitment.job_shortlist(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    shortlist_source_type_id bigint NOT NULL REFERENCES sourcing.shortlist_source_type(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    outreach_recipient_id bigint NULL REFERENCES sourcing.outreach_recipient(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    sourcing_request_id bigint NULL REFERENCES sourcing.sourcing_request(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    added_by_user_id bigint NOT NULL REFERENCES administration.user_account(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    created_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by bigint NOT NULL REFERENCES administration.user_account(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    updated_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by bigint NOT NULL REFERENCES administration.user_account(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    CONSTRAINT uq_sourcing_shortlist_entry_shortlist_candidate UNIQUE (job_shortlist_candidate_id)
);

CREATE INDEX idx_sourcing_shortlist_entry_sourcing_request_id ON sourcing.sourcing_shortlist_entry(sourcing_request_id);
CREATE INDEX idx_sourcing_shortlist_entry_outreach_recipient ON sourcing.sourcing_shortlist_entry(outreach_recipient_id);
CREATE INDEX idx_sourcing_shortlist_entry_source_type ON sourcing.sourcing_shortlist_entry(shortlist_source_type_id);
CREATE INDEX idx_sourcing_shortlist_entry_added_by ON sourcing.sourcing_shortlist_entry(added_by_user_id);

-- ============================================================================
-- 4. TRIGGERS & ENFORCEMENT PROCEDURES (Section 3.4 B46)
-- ============================================================================

-- A. Append-only enforcement
CREATE TRIGGER trg_sourcing_request_decision_append_only
BEFORE UPDATE OR DELETE ON sourcing.sourcing_request_decision
FOR EACH ROW EXECUTE FUNCTION enforce_append_only();

CREATE TRIGGER trg_job_consultant_openness_event_append_only
BEFORE UPDATE OR DELETE ON sourcing.job_consultant_openness_event
FOR EACH ROW EXECUTE FUNCTION enforce_append_only();

-- B. Updated_at maintenance triggers
CREATE TRIGGER trg_sourcing_request_updated_at
BEFORE UPDATE ON sourcing.sourcing_request
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_outreach_batch_updated_at
BEFORE UPDATE ON sourcing.outreach_batch
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_outreach_recipient_updated_at
BEFORE UPDATE ON sourcing.outreach_recipient
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_sourcing_shortlist_entry_updated_at
BEFORE UPDATE ON sourcing.sourcing_shortlist_entry
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- C. Guard: Consultant acts only on jobs open to consultants and not blocked
CREATE OR REPLACE FUNCTION sourcing.fn_sourcing_request_guard()
RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE
    v_is_open boolean;
    v_org_id bigint;
    v_is_blocked boolean;
BEGIN
    SELECT open_to_consultants, organisation_id 
    INTO v_is_open, v_org_id
    FROM recruitment.job_requirement
    WHERE id = NEW.job_requirement_id;

    IF v_is_open IS NOT TRUE THEN
        RAISE EXCEPTION 'Job requirement % is not currently open to external consultants', NEW.job_requirement_id;
    END IF;

    SELECT EXISTS (
        SELECT 1 FROM administration.organisation_block
        WHERE organisation_id = v_org_id AND user_id = NEW.consultant_user_id
    ) OR EXISTS (
        SELECT 1 FROM administration.user_block
        WHERE blocker_user_id = NEW.consultant_user_id
    ) INTO v_is_blocked;

    IF v_is_blocked IS TRUE THEN
        RAISE EXCEPTION 'Consultant % is blocked from collaborating with organisation %', NEW.consultant_user_id, v_org_id;
    END IF;

    RETURN NEW;
END $$;

CREATE TRIGGER trg_sourcing_request_guard
BEFORE INSERT ON sourcing.sourcing_request
FOR EACH ROW EXECUTE FUNCTION sourcing.fn_sourcing_request_guard();

-- D. Update sourcing_request status and closed_at upon decision insert
CREATE OR REPLACE FUNCTION sourcing.fn_sourcing_request_decision_sync()
RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE
    v_decision_code varchar(50);
    v_status_id bigint;
    v_org_id bigint;
    v_is_org_member boolean;
BEGIN
    -- Verify decider belongs to job's organisation
    SELECT jr.organisation_id INTO v_org_id
    FROM sourcing.sourcing_request sr
    JOIN recruitment.job_requirement jr ON jr.id = sr.job_requirement_id
    WHERE sr.id = NEW.sourcing_request_id;

    SELECT EXISTS (
        SELECT 1 FROM organisation.organisation_recruiter
        WHERE organisation_id = v_org_id AND user_account_id = NEW.decided_by_user_id AND is_active = true
    ) OR EXISTS (
        SELECT 1 FROM organisation.account_administrator aa
        JOIN organisation.account a ON a.id = aa.account_id
        WHERE a.organisation_id = v_org_id AND aa.user_account_id = NEW.decided_by_user_id AND aa.is_active = true
    ) INTO v_is_org_member;

    IF v_is_org_member IS NOT TRUE THEN
        -- Allow system administrator fallback (user_id = 1 or super_admin role)
        IF NEW.decided_by_user_id <> 1 THEN
            RAISE EXCEPTION 'Decider user % does not belong to the organisation owning the job', NEW.decided_by_user_id;
        END IF;
    END IF;

    SELECT code INTO v_decision_code 
    FROM sourcing.decision_type 
    WHERE id = NEW.decision_type_id;

    IF v_decision_code = 'declined' AND NEW.decline_reason_id IS NULL THEN
        RAISE EXCEPTION 'decline_reason_id is mandatory when declining a sourcing request';
    END IF;

    SELECT id INTO v_status_id
    FROM sourcing.sourcing_request_status
    WHERE code = v_decision_code;

    IF v_status_id IS NOT NULL THEN
        UPDATE sourcing.sourcing_request
        SET sourcing_request_status_id = v_status_id,
            closed_at = CASE 
                WHEN v_decision_code IN ('declined', 'withdrawn', 'revoked') THEN NEW.decided_at
                ELSE closed_at
            END,
            updated_at = CURRENT_TIMESTAMP
        WHERE id = NEW.sourcing_request_id;
    END IF;

    RETURN NEW;
END $$;

CREATE TRIGGER trg_sourcing_request_decision_sync
AFTER INSERT ON sourcing.sourcing_request_decision
FOR EACH ROW EXECUTE FUNCTION sourcing.fn_sourcing_request_decision_sync();

-- E. Guard: Shortlist source type foreign key consistency
CREATE OR REPLACE FUNCTION sourcing.fn_shortlist_source_type_guard()
RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE
    v_source_code varchar(50);
BEGIN
    SELECT code INTO v_source_code 
    FROM sourcing.shortlist_source_type 
    WHERE id = NEW.shortlist_source_type_id;

    IF v_source_code = 'outreach_response' AND NEW.outreach_recipient_id IS NULL THEN
        RAISE EXCEPTION 'outreach_recipient_id is required when shortlist source is outreach_response';
    END IF;

    IF v_source_code = 'consultant_submission' AND NEW.sourcing_request_id IS NULL THEN
        RAISE EXCEPTION 'sourcing_request_id is required when shortlist source is consultant_submission';
    END IF;

    RETURN NEW;
END $$;

CREATE TRIGGER trg_shortlist_source_type_guard
BEFORE INSERT OR UPDATE ON sourcing.sourcing_shortlist_entry
FOR EACH ROW EXECUTE FUNCTION sourcing.fn_shortlist_source_type_guard();

-- F. Dynamic outreach batch recipient counter maintenance
CREATE OR REPLACE FUNCTION sourcing.fn_maintain_batch_recipient_count()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        UPDATE sourcing.outreach_batch
        SET recipient_count = recipient_count + 1, updated_at = CURRENT_TIMESTAMP
        WHERE id = NEW.outreach_batch_id;
        RETURN NEW;
    ELSIF TG_OP = 'DELETE' THEN
        UPDATE sourcing.outreach_batch
        SET recipient_count = GREATEST(0, recipient_count - 1), updated_at = CURRENT_TIMESTAMP
        WHERE id = OLD.outreach_batch_id;
        RETURN OLD;
    END IF;
    RETURN NULL;
END $$;

CREATE TRIGGER trg_outreach_recipient_count_maintain
AFTER INSERT OR DELETE ON sourcing.outreach_recipient
FOR EACH ROW EXECUTE FUNCTION sourcing.fn_maintain_batch_recipient_count();

-- G. Openness logger trigger on recruitment.job_requirement
CREATE OR REPLACE FUNCTION sourcing.fn_log_job_consultant_openness()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
    IF OLD.open_to_consultants IS DISTINCT FROM NEW.open_to_consultants THEN
        INSERT INTO sourcing.job_consultant_openness_event (
            job_requirement_id, is_open, set_by_user_id, set_at, created_by
        )
        VALUES (
            NEW.id, NEW.open_to_consultants,
            COALESCE(NEW.updated_by, NEW.created_by, 1),
            CURRENT_TIMESTAMP,
            COALESCE(NEW.updated_by, NEW.created_by, 1)
        );
    END IF;
    RETURN NEW;
END $$;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_trigger WHERE tgname = 'trg_job_consultant_openness_logger'
    ) THEN
        CREATE TRIGGER trg_job_consultant_openness_logger
        AFTER UPDATE OF open_to_consultants ON recruitment.job_requirement
        FOR EACH ROW EXECUTE FUNCTION sourcing.fn_log_job_consultant_openness();
    END IF;
END $$;

-- ============================================================================
-- 5. FUZZY SEARCH GIN TRIGRAM INDEXES (pg_trgm)
-- ============================================================================

CREATE INDEX idx_outreach_batch_name_trgm ON sourcing.outreach_batch USING gin (batch_name gin_trgm_ops);

-- ============================================================================
-- 6. ROW-LEVEL SECURITY POLICIES (Rule Group 9)
-- ============================================================================

ALTER TABLE sourcing.sourcing_request ENABLE ROW LEVEL SECURITY;
ALTER TABLE sourcing.outreach_batch ENABLE ROW LEVEL SECURITY;
ALTER TABLE sourcing.outreach_recipient ENABLE ROW LEVEL SECURITY;
ALTER TABLE sourcing.sourcing_shortlist_entry ENABLE ROW LEVEL SECURITY;

-- ============================================================================
-- 7. ACTIVE CONVENIENCE & C-SUITE ANALYTICAL VIEWS
-- ============================================================================

CREATE OR REPLACE VIEW sourcing.v_active_sourcing_request AS
SELECT 
    sr.id AS sourcing_request_id,
    sr.job_requirement_id,
    jr.job_title,
    jr.organisation_id,
    o.legal_name AS organisation_name,
    sr.consultant_user_id,
    u.full_name AS consultant_name,
    srs.code AS request_status_code,
    sr.requested_at,
    sr.note
FROM sourcing.sourcing_request sr
JOIN recruitment.job_requirement jr ON jr.id = sr.job_requirement_id
JOIN organisation.organisation o ON o.id = jr.organisation_id
JOIN administration.user_account u ON u.id = sr.consultant_user_id
JOIN sourcing.sourcing_request_status srs ON srs.id = sr.sourcing_request_status_id
WHERE sr.closed_at IS NULL;

CREATE OR REPLACE VIEW sourcing.v_outreach_campaign_performance AS
SELECT 
    ob.id AS outreach_batch_id,
    ob.job_requirement_id,
    ob.organisation_id,
    ob.batch_name,
    ob.recipient_count,
    COUNT(CASE WHEN r.contacted_at IS NOT NULL THEN 1 END) AS contacted_count,
    COUNT(CASE WHEN r.responded_at IS NOT NULL THEN 1 END) AS responded_count,
    ROUND(
        (COUNT(CASE WHEN r.responded_at IS NOT NULL THEN 1 END)::numeric / NULLIF(ob.recipient_count, 0)) * 100, 2
    ) AS response_rate_percentage
FROM sourcing.outreach_batch ob
LEFT JOIN sourcing.outreach_recipient r ON r.outreach_batch_id = ob.id
GROUP BY ob.id, ob.job_requirement_id, ob.organisation_id, ob.batch_name, ob.recipient_count;

COMMIT;
