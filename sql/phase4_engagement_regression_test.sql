-- ============================================================================
-- Talentra Enterprise: Phase 4 Module A (Engagement & Community) Regression Suite
-- Tests ENG-001 through ENG-012 with transaction-isolated rollback guarantees.
-- ============================================================================

\set ON_ERROR_STOP on

BEGIN;

DO $$
DECLARE
    v_admin_id bigint;
    v_cand_id bigint;
    v_lang_id bigint;
    v_channel_email_id bigint;
    v_type_alert_id bigint;
    v_temp_id bigint;
    v_notif_id bigint;
    v_del_id bigint;
    v_prov_id bigint;
    v_out_id bigint;
    v_status_q_id bigint;
    v_criteria_id bigint;
    v_topic_id bigint;
    v_post_id bigint;
    v_reason_id bigint;
    v_rev_id bigint;
    v_tk_cat_id bigint;
    v_tk_stat_id bigint;
    v_tk_pri_id bigint;
    v_ref_code_id bigint;
    v_ref_type_id bigint;
    v_ref_src_id bigint;
    v_attempt_id bigint;
    v_bad boolean := false;
BEGIN
    RAISE NOTICE '>>> RUNNING PHASE 4 MODULE A (ENGAGEMENT & COMMUNITY) REGRESSION SUITE...';

    SELECT id INTO v_admin_id FROM administration.user_account ORDER BY id LIMIT 1;
    SELECT id INTO v_cand_id FROM administration.user_account ORDER BY id DESC LIMIT 1;
    SELECT id INTO v_lang_id FROM master_data.language ORDER BY id LIMIT 1;
    SELECT id INTO v_channel_email_id FROM engagement.notification_channel WHERE code = 'email';
    SELECT id INTO v_type_alert_id FROM engagement.notification_type WHERE code = 'job_alert';
    SELECT id INTO v_prov_id FROM engagement.notification_provider WHERE code = 'ses_aws';
    SELECT id INTO v_out_id FROM engagement.notification_delivery_outcome WHERE code = 'success';
    SELECT id INTO v_status_q_id FROM engagement.notification_delivery_status WHERE code = 'queued';
    SELECT id INTO v_topic_id FROM engagement.community_topic WHERE slug = 'database-engineering';
    SELECT id INTO v_reason_id FROM engagement.report_reason WHERE code = 'spam';
    SELECT id INTO v_rev_id FROM engagement.review_status WHERE code = 'unreviewed';
    SELECT id INTO v_tk_cat_id FROM engagement.ticket_category WHERE code = 'billing_inquiry';
    SELECT id INTO v_tk_stat_id FROM engagement.ticket_status WHERE code = 'open';
    SELECT id INTO v_tk_pri_id FROM engagement.ticket_priority WHERE code = 'normal';
    SELECT id INTO v_ref_type_id FROM engagement.referral_event_type WHERE code = 'signup_completed';
    SELECT id INTO v_ref_src_id FROM engagement.referral_source_channel WHERE code = 'direct_link';

    -- ENG-001: Template uniqueness on (type, channel)
    BEGIN
        v_bad := false;
        INSERT INTO engagement.notification_template (
            notification_type_id, notification_channel_id, subject_label_key, created_by, updated_by
        ) VALUES (
            v_type_alert_id, v_channel_email_id, 'dup.subject', v_admin_id, v_admin_id
        );
        -- Insert duplicate
        INSERT INTO engagement.notification_template (
            notification_type_id, notification_channel_id, subject_label_key, created_by, updated_by
        ) VALUES (
            v_type_alert_id, v_channel_email_id, 'dup.subject.2', v_admin_id, v_admin_id
        );
        v_bad := true;
    EXCEPTION WHEN unique_violation THEN NULL;
    END;
    IF v_bad THEN RAISE EXCEPTION 'ENG-001 FAILED: Duplicate notification template accepted'; END IF;
    RAISE NOTICE 'ENG-001 PASSED: Notification template unique pair verified';

    -- ENG-002: Notification creation with JSONB parameters
    INSERT INTO engagement.notification (
        notification_type_id, notification_template_id, template_params,
        source_entity_name, source_entity_id, created_by
    )
    VALUES (
        v_type_alert_id, (SELECT id FROM engagement.notification_template LIMIT 1),
        '{"alert_name": "Senior SRE", "count": 5}'::jsonb, 'job_alert', 1, v_admin_id
    ) RETURNING id INTO v_notif_id;
    RAISE NOTICE 'ENG-002 PASSED: Notification created with JSONB payload (id=%)', v_notif_id;

    -- ENG-003: Delivery scheduled order validation
    BEGIN
        v_bad := false;
        INSERT INTO engagement.notification_delivery (
            notification_created_at, notification_id, recipient_user_account_id,
            notification_channel_id, notification_delivery_status_id, scheduled_at, sent_at, created_by
        ) VALUES (
            '2026-10-21 10:00:00+00', v_notif_id, v_cand_id,
            v_channel_email_id, v_status_q_id, '2026-10-21 10:00:00+00', '2026-10-21 09:00:00+00', v_admin_id
        );
        v_bad := true;
    EXCEPTION WHEN check_violation THEN NULL;
    END;
    IF v_bad THEN RAISE EXCEPTION 'ENG-003 FAILED: Delivery accepted with sent_at before created_at'; END IF;
    RAISE NOTICE 'ENG-003 PASSED: Delivery temporal sent_at check verified';

    -- ENG-004: Delivery attempt append-only immutability
    INSERT INTO engagement.notification_delivery_attempt (
        notification_delivery_id, notification_created_at, attempt_number,
        notification_provider_id, delivery_outcome_id, attempted_at
    ) VALUES (
        99999, '2026-10-21 10:00:00+00', 1, v_prov_id, v_out_id, '2026-10-21 10:01:00+00'
    ) RETURNING id INTO v_attempt_id;

    BEGIN
        v_bad := false;
        DELETE FROM engagement.notification_delivery_attempt WHERE id = v_attempt_id AND attempted_at = '2026-10-21 10:01:00+00';
        v_bad := true;
    EXCEPTION WHEN raise_exception THEN NULL;
    END;
    IF v_bad THEN RAISE EXCEPTION 'ENG-004 FAILED: Delivery attempt delete permitted on append-only table'; END IF;
    RAISE NOTICE 'ENG-004 PASSED: Delivery attempt append-only immutability verified';

    -- ENG-005: Provider event inbox idempotency
    INSERT INTO engagement.provider_event_inbox (
        notification_provider_id, provider_event_id, payload_hash
    ) VALUES (
        v_prov_id, 'evt-idemp-001', '\x01020304'::bytea
    );
    BEGIN
        v_bad := false;
        INSERT INTO engagement.provider_event_inbox (
            notification_provider_id, provider_event_id, payload_hash
        ) VALUES (
            v_prov_id, 'evt-idemp-001', '\x01020304'::bytea
        );
        v_bad := true;
    EXCEPTION WHEN unique_violation THEN NULL;
    END;
    IF v_bad THEN RAISE EXCEPTION 'ENG-005 FAILED: Duplicate provider event ID accepted'; END IF;
    RAISE NOTICE 'ENG-005 PASSED: Provider event inbox webhook idempotency verified';

    -- ENG-006: Contact suppression active uniqueness
    INSERT INTO engagement.contact_suppression (
        user_account_id, notification_channel_id, reason, destination_hash, created_by, updated_by
    ) VALUES (
        v_cand_id, v_channel_email_id, 'unsubscribed', sha256('candidate@test.com'::bytea), v_admin_id, v_admin_id
    );
    BEGIN
        v_bad := false;
        INSERT INTO engagement.contact_suppression (
            user_account_id, notification_channel_id, reason, destination_hash, created_by, updated_by
        ) VALUES (
            v_cand_id, v_channel_email_id, 'bounced', sha256('candidate@test.com'::bytea), v_admin_id, v_admin_id
        );
        v_bad := true;
    EXCEPTION WHEN unique_violation THEN NULL;
    END;
    IF v_bad THEN RAISE EXCEPTION 'ENG-006 FAILED: Duplicate active suppression allowed for same channel'; END IF;
    RAISE NOTICE 'ENG-006 PASSED: Active contact suppression partial uniqueness verified';

    -- ENG-007: Follow relation exactly-one target constraint
    BEGIN
        v_bad := false;
        INSERT INTO engagement.follow_relation (
            follower_user_account_id, followed_user_account_id, followed_organisation_id, followed_community_topic_id, created_by, updated_by
        ) VALUES (
            v_cand_id, v_admin_id, 1, NULL, v_admin_id, v_admin_id
        );
        v_bad := true;
    EXCEPTION WHEN check_violation THEN NULL;
    END;
    IF v_bad THEN RAISE EXCEPTION 'ENG-007 FAILED: Follow relation accepted with two targets'; END IF;
    RAISE NOTICE 'ENG-007 PASSED: Follow relation exactly-one target constraint verified';

    -- ENG-008: Follow relation self-follow prevention
    BEGIN
        v_bad := false;
        INSERT INTO engagement.follow_relation (
            follower_user_account_id, followed_user_account_id, followed_organisation_id, followed_community_topic_id, created_by, updated_by
        ) VALUES (
            v_cand_id, v_cand_id, NULL, NULL, v_admin_id, v_admin_id
        );
        v_bad := true;
    EXCEPTION WHEN check_violation THEN NULL;
    END;
    IF v_bad THEN RAISE EXCEPTION 'ENG-008 FAILED: User allowed to self-follow'; END IF;
    RAISE NOTICE 'ENG-008 PASSED: Self-follow prevention constraint verified';

    -- ENG-009: Community post length constraint
    BEGIN
        v_bad := false;
        INSERT INTO engagement.community_post (
            author_user_account_id, content_text, content_language_id, visibility_level_id, moderation_status_id, created_by, updated_by
        ) VALUES (
            v_admin_id, repeat('x', 20005), v_lang_id, (SELECT id FROM engagement.visibility_level LIMIT 1), (SELECT id FROM engagement.moderation_status LIMIT 1), v_admin_id, v_admin_id
        );
        v_bad := true;
    EXCEPTION WHEN check_violation THEN NULL;
    END;
    IF v_bad THEN RAISE EXCEPTION 'ENG-009 FAILED: Post exceeding 20,000 chars accepted'; END IF;
    RAISE NOTICE 'ENG-009 PASSED: Community post prose character cap verified';

    -- ENG-010: Community report exactly-one target constraint
    BEGIN
        v_bad := false;
        INSERT INTO engagement.community_report (
            community_post_id, community_comment_id, reported_user_account_id,
            reporter_user_account_id, report_reason_id, review_status_id, created_by, updated_by
        ) VALUES (
            NULL, NULL, NULL,
            v_cand_id, v_reason_id, v_rev_id, v_cand_id, v_cand_id
        );
        v_bad := true;
    EXCEPTION WHEN check_violation THEN NULL;
    END;
    IF v_bad THEN RAISE EXCEPTION 'ENG-010 FAILED: Community report accepted with zero targets'; END IF;
    RAISE NOTICE 'ENG-010 PASSED: Community report exactly-one target constraint verified';

    -- ENG-011: Support ticket closed order check
    BEGIN
        v_bad := false;
        INSERT INTO engagement.support_ticket (
            requester_user_account_id, ticket_category_id, ticket_status_id, ticket_priority_id,
            subject, closed_at, created_at, created_by, updated_by
        ) VALUES (
            v_cand_id, v_tk_cat_id, v_tk_stat_id, v_tk_pri_id,
            'Billing Query', '2026-10-21 08:00:00+00', '2026-10-21 10:00:00+00', v_cand_id, v_cand_id
        );
        v_bad := true;
    EXCEPTION WHEN check_violation THEN NULL;
    END;
    IF v_bad THEN RAISE EXCEPTION 'ENG-011 FAILED: Ticket closed before created'; END IF;
    RAISE NOTICE 'ENG-011 PASSED: Support ticket closed_at >= created_at check verified';

    -- ENG-012: Referral event self-referral prevention
    SELECT id INTO v_ref_code_id FROM engagement.referral_code LIMIT 1;
    BEGIN
        v_bad := false;
        INSERT INTO engagement.referral_event (
            referral_code_id, referrer_user_account_id, referred_user_account_id,
            referral_event_type_id, referral_source_channel_id
        ) VALUES (
            v_ref_code_id, v_cand_id, v_cand_id,
            v_ref_type_id, v_ref_src_id
        );
        v_bad := true;
    EXCEPTION WHEN check_violation THEN NULL;
    END;
    IF v_bad THEN RAISE EXCEPTION 'ENG-012 FAILED: User allowed to self-refer'; END IF;
    RAISE NOTICE 'ENG-012 PASSED: Self-referral prevention constraint verified';

    RAISE NOTICE '>>> ALL 12 ENGAGEMENT & COMMUNITY REGRESSION TEST SCENARIOS PASSED!';
END $$;

ROLLBACK;
