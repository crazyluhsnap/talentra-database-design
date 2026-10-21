-- ============================================================================
-- Talentra Enterprise: Phase 3 Module A (Sourcing) Seed Data
-- ============================================================================

\set ON_ERROR_STOP on

BEGIN;

-- 1. Sourcing Request Status
INSERT INTO sourcing.sourcing_request_status (code, name_key, is_active, sort_order)
VALUES 
    ('pending', 'sourcing.status.pending', true, 1),
    ('accepted', 'sourcing.status.accepted', true, 2),
    ('declined', 'sourcing.status.declined', true, 3),
    ('withdrawn', 'sourcing.status.withdrawn', true, 4),
    ('revoked', 'sourcing.status.revoked', true, 5)
ON CONFLICT (code) DO NOTHING;

-- 2. Decision Type
INSERT INTO sourcing.decision_type (code, name_key, is_active, sort_order)
VALUES 
    ('accepted', 'sourcing.decision.accepted', true, 1),
    ('declined', 'sourcing.decision.declined', true, 2),
    ('withdrawn', 'sourcing.decision.withdrawn', true, 3),
    ('revoked', 'sourcing.decision.revoked', true, 4)
ON CONFLICT (code) DO NOTHING;

-- 3. Decision Reason
INSERT INTO sourcing.decision_reason (code, name_key, is_active, sort_order)
VALUES 
    ('not_a_fit', 'sourcing.reason.not_a_fit', true, 1),
    ('position_filled', 'sourcing.reason.position_filled', true, 2),
    ('budget', 'sourcing.reason.budget', true, 3),
    ('duplicate_consultant', 'sourcing.reason.duplicate_consultant', true, 4),
    ('other', 'sourcing.reason.other', true, 5)
ON CONFLICT (code) DO NOTHING;

-- 4. Outreach Batch Status
INSERT INTO sourcing.outreach_batch_status (code, name_key, is_active, sort_order)
VALUES 
    ('draft', 'sourcing.batch.draft', true, 1),
    ('scheduled', 'sourcing.batch.scheduled', true, 2),
    ('sending', 'sourcing.batch.sending', true, 3),
    ('completed', 'sourcing.batch.completed', true, 4),
    ('cancelled', 'sourcing.batch.cancelled', true, 5),
    ('failed', 'sourcing.batch.failed', true, 6)
ON CONFLICT (code) DO NOTHING;

-- 5. Outreach Recipient Status
INSERT INTO sourcing.outreach_recipient_status (code, name_key, is_active, sort_order)
VALUES 
    ('queued', 'sourcing.recipient.queued', true, 1),
    ('sent', 'sourcing.recipient.sent', true, 2),
    ('delivered', 'sourcing.recipient.delivered', true, 3),
    ('failed', 'sourcing.recipient.failed', true, 4),
    ('responded', 'sourcing.recipient.responded', true, 5),
    ('declined', 'sourcing.recipient.declined', true, 6)
ON CONFLICT (code) DO NOTHING;

-- 6. Outreach Channel
INSERT INTO sourcing.outreach_channel (code, name_key, is_active, sort_order)
VALUES 
    ('email', 'sourcing.channel.email', true, 1),
    ('sms', 'sourcing.channel.sms', true, 2),
    ('app_message', 'sourcing.channel.app_message', true, 3)
ON CONFLICT (code) DO NOTHING;

-- 7. Shortlist Source Type
INSERT INTO sourcing.shortlist_source_type (code, name_key, is_active, sort_order)
VALUES 
    ('outreach_response', 'sourcing.source.outreach_response', true, 1),
    ('consultant_submission', 'sourcing.source.consultant_submission', true, 2),
    ('manual', 'sourcing.source.manual', true, 3)
ON CONFLICT (code) DO NOTHING;

-- 8. Seed Sample Sourcing Request Fixture
DO $$
DECLARE
    v_job_id bigint;
    v_consultant_id bigint;
    v_status_pending_id bigint;
    v_org_id bigint;
    v_batch_status_id bigint;
    v_channel_email_id bigint;
    v_batch_id bigint;
    v_candidate_id bigint;
    v_recipient_queued_id bigint;
BEGIN
    SELECT id, organisation_id INTO v_job_id, v_org_id 
    FROM recruitment.job_requirement 
    ORDER BY id LIMIT 1;

    SELECT id INTO v_consultant_id 
    FROM administration.user_account 
    ORDER BY id LIMIT 1;

    SELECT id INTO v_status_pending_id 
    FROM sourcing.sourcing_request_status 
    WHERE code = 'pending';

    SELECT id INTO v_batch_status_id 
    FROM sourcing.outreach_batch_status 
    WHERE code = 'completed';

    SELECT id INTO v_channel_email_id 
    FROM sourcing.outreach_channel 
    WHERE code = 'email';

    SELECT id INTO v_candidate_id 
    FROM profile.candidate_profile 
    ORDER BY id LIMIT 1;

    SELECT id INTO v_recipient_queued_id 
    FROM sourcing.outreach_recipient_status 
    WHERE code = 'queued';

    IF v_job_id IS NOT NULL AND v_consultant_id IS NOT NULL AND v_status_pending_id IS NOT NULL THEN
        -- Make sure job is open to consultants for demo fixture
        UPDATE recruitment.job_requirement
        SET open_to_consultants = true
        WHERE id = v_job_id;

        INSERT INTO sourcing.sourcing_request (
            job_requirement_id, consultant_user_id, sourcing_request_status_id,
            requested_at, note, created_by, updated_by
        )
        VALUES (
            v_job_id, v_consultant_id, v_status_pending_id,
            CURRENT_TIMESTAMP - interval '3 days',
            'Experienced technical recruiter with immediate access to 5 senior distributed systems engineers.',
            v_consultant_id, v_consultant_id
        )
        ON CONFLICT DO NOTHING;

        -- Create sample outreach batch
        IF v_org_id IS NOT NULL AND v_batch_status_id IS NOT NULL AND v_channel_email_id IS NOT NULL THEN
            INSERT INTO sourcing.outreach_batch (
                job_requirement_id, organisation_id, initiated_by_user_id,
                outreach_channel_id, outreach_batch_status_id, batch_name,
                idempotency_key, sent_at, recipient_count, created_by, updated_by
            )
            VALUES (
                v_job_id, v_org_id, v_consultant_id,
                v_channel_email_id, v_batch_status_id, 'Q4 Senior Cloud Architect Direct Outreach',
                'seed-outreach-batch-' || v_job_id, CURRENT_TIMESTAMP - interval '2 days', 1,
                v_consultant_id, v_consultant_id
            )
            ON CONFLICT (organisation_id, idempotency_key) DO NOTHING
            RETURNING id INTO v_batch_id;

            IF v_batch_id IS NULL THEN
                SELECT id INTO v_batch_id FROM sourcing.outreach_batch 
                WHERE organisation_id = v_org_id AND idempotency_key = 'seed-outreach-batch-' || v_job_id;
            END IF;

            -- Create sample recipient
            IF v_batch_id IS NOT NULL AND v_candidate_id IS NOT NULL AND v_recipient_queued_id IS NOT NULL THEN
                INSERT INTO sourcing.outreach_recipient (
                    outreach_batch_id, candidate_profile_id, outreach_recipient_status_id,
                    contacted_at, created_by, updated_by
                )
                VALUES (
                    v_batch_id, v_candidate_id, v_recipient_queued_id,
                    CURRENT_TIMESTAMP - interval '2 days', v_consultant_id, v_consultant_id
                )
                ON CONFLICT (outreach_batch_id, candidate_profile_id) DO NOTHING;
            END IF;
        END IF;
    END IF;
END $$;

COMMIT;
