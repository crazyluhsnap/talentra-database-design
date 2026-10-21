-- ============================================================================
-- Talentra Enterprise: Phase 4 Module A (Engagement & Community) Seed Data
-- ============================================================================

\set ON_ERROR_STOP on

BEGIN;

DO $$
DECLARE
    v_admin_id bigint;
    v_candidate_user_id bigint;
    v_lang_en_id bigint;
    v_channel_email_id bigint;
    v_channel_app_id bigint;
    v_type_job_alert_id bigint;
    v_type_security_id bigint;
    v_freq_daily_id bigint;
    v_status_open_id bigint;
    v_vis_public_id bigint;
    v_vis_recruiters_id bigint;
    v_template_alert_id bigint;
    v_criteria_id bigint;
    v_alert_id bigint;
    v_topic_ai_id bigint;
    v_post_id bigint;
    v_faq_cat_gen_id bigint;
    v_faq_id bigint;
    v_ref_code_id bigint;
BEGIN
    SELECT id INTO v_admin_id FROM administration.user_account ORDER BY id LIMIT 1;
    SELECT id INTO v_candidate_user_id FROM administration.user_account ORDER BY id DESC LIMIT 1;
    SELECT id INTO v_lang_en_id FROM master_data.language WHERE code = 'en';
    IF v_lang_en_id IS NULL THEN SELECT id INTO v_lang_en_id FROM master_data.language ORDER BY id LIMIT 1; END IF;

    IF v_admin_id IS NOT NULL THEN
        -- 0. Master Data Job Categories (Mandated Eight Categories)
        INSERT INTO master_data.job_category (code, category_name, is_active, sort_order, created_by, updated_by)
        VALUES 
            ('gig', 'Gig Marketplace', true, 1, v_admin_id, v_admin_id),
            ('general_staffing', 'General Staffing', true, 2, v_admin_id, v_admin_id),
            ('professional_staffing', 'Professional Staffing', true, 3, v_admin_id, v_admin_id),
            ('permanent', 'Permanent Placement', true, 4, v_admin_id, v_admin_id),
            ('apprentice', 'Apprenticeship & Internships', true, 5, v_admin_id, v_admin_id),
            ('campus', 'Campus Recruitment', true, 6, v_admin_id, v_admin_id),
            ('consultant_marketplace', 'Consultant Marketplace', true, 7, v_admin_id, v_admin_id),
            ('managed_remote', 'Managed Remote Operations', true, 8, v_admin_id, v_admin_id)
        ON CONFLICT (code) DO NOTHING;

        -- 1. Notification Types
        INSERT INTO engagement.notification_type (code, label_key, is_mandatory, is_active, sort_order, created_by, updated_by)
        VALUES 
            ('job_alert', 'engagement.type.job_alert', false, true, 1, v_admin_id, v_admin_id),
            ('security_alert', 'engagement.type.security_alert', true, true, 2, v_admin_id, v_admin_id),
            ('billing_notice', 'engagement.type.billing_notice', true, true, 3, v_admin_id, v_admin_id),
            ('application_status', 'engagement.type.application_status', false, true, 4, v_admin_id, v_admin_id),
            ('community_mention', 'engagement.type.community_mention', false, true, 5, v_admin_id, v_admin_id),
            ('referral_reward', 'engagement.type.referral_reward', false, true, 6, v_admin_id, v_admin_id)
        ON CONFLICT (code) DO NOTHING;

        -- 2. Notification Channels
        INSERT INTO engagement.notification_channel (code, label_key, is_active, sort_order, created_by, updated_by)
        VALUES 
            ('email', 'engagement.channel.email', true, 1, v_admin_id, v_admin_id),
            ('in_app', 'engagement.channel.in_app', true, 2, v_admin_id, v_admin_id),
            ('sms', 'engagement.channel.sms', true, 3, v_admin_id, v_admin_id),
            ('push', 'engagement.channel.push', true, 4, v_admin_id, v_admin_id)
        ON CONFLICT (code) DO NOTHING;

        -- 3. Delivery Statuses & Outcomes
        INSERT INTO engagement.notification_delivery_status (code, label_key, is_active, sort_order, created_by, updated_by)
        VALUES 
            ('queued', 'engagement.status.queued', true, 1, v_admin_id, v_admin_id),
            ('sending', 'engagement.status.sending', true, 2, v_admin_id, v_admin_id),
            ('delivered', 'engagement.status.delivered', true, 3, v_admin_id, v_admin_id),
            ('failed', 'engagement.status.failed', true, 4, v_admin_id, v_admin_id)
        ON CONFLICT (code) DO NOTHING;

        INSERT INTO engagement.notification_delivery_outcome (code, label_key, is_active, sort_order, created_by, updated_by)
        VALUES 
            ('success', 'engagement.outcome.success', true, 1, v_admin_id, v_admin_id),
            ('bounced', 'engagement.outcome.bounced', true, 2, v_admin_id, v_admin_id),
            ('throttled', 'engagement.outcome.throttled', true, 3, v_admin_id, v_admin_id),
            ('rejected', 'engagement.outcome.rejected', true, 4, v_admin_id, v_admin_id)
        ON CONFLICT (code) DO NOTHING;

        -- 4. Notification Providers
        INSERT INTO engagement.notification_provider (code, label_key, is_degraded, is_active, sort_order, created_by, updated_by)
        VALUES 
            ('ses_aws', 'engagement.provider.ses', false, true, 1, v_admin_id, v_admin_id),
            ('sendgrid', 'engagement.provider.sendgrid', false, true, 2, v_admin_id, v_admin_id),
            ('twilio_sms', 'engagement.provider.twilio', false, true, 3, v_admin_id, v_admin_id),
            ('firebase_fcm', 'engagement.provider.fcm', false, true, 4, v_admin_id, v_admin_id)
        ON CONFLICT (code) DO NOTHING;

        -- 5. Alert Frequencies
        INSERT INTO engagement.alert_frequency (code, label_key, is_active, sort_order, created_by, updated_by)
        VALUES 
            ('instant', 'engagement.frequency.instant', true, 1, v_admin_id, v_admin_id),
            ('daily', 'engagement.frequency.daily', true, 2, v_admin_id, v_admin_id),
            ('weekly', 'engagement.frequency.weekly', true, 3, v_admin_id, v_admin_id)
        ON CONFLICT (code) DO NOTHING;

        -- 6. Visibility Levels & Open to Work
        INSERT INTO engagement.visibility_level (code, label_key, is_active, sort_order, created_by, updated_by)
        VALUES 
            ('public', 'engagement.visibility.public', true, 1, v_admin_id, v_admin_id),
            ('recruiters_only', 'engagement.visibility.recruiters_only', true, 2, v_admin_id, v_admin_id),
            ('private', 'engagement.visibility.private', true, 3, v_admin_id, v_admin_id)
        ON CONFLICT (code) DO NOTHING;

        INSERT INTO engagement.open_to_work_status (code, label_key, is_active, sort_order, created_by, updated_by)
        VALUES 
            ('actively_looking', 'engagement.otw.actively_looking', true, 1, v_admin_id, v_admin_id),
            ('open_to_offers', 'engagement.otw.open_to_offers', true, 2, v_admin_id, v_admin_id),
            ('not_looking', 'engagement.otw.not_looking', true, 3, v_admin_id, v_admin_id)
        ON CONFLICT (code) DO NOTHING;

        -- 7. Community Lookups
        INSERT INTO engagement.reaction_type (code, label_key, is_active, sort_order, created_by, updated_by)
        VALUES 
            ('like', 'engagement.reaction.like', true, 1, v_admin_id, v_admin_id),
            ('celebrate', 'engagement.reaction.celebrate', true, 2, v_admin_id, v_admin_id),
            ('insightful', 'engagement.reaction.insightful', true, 3, v_admin_id, v_admin_id),
            ('curious', 'engagement.reaction.curious', true, 4, v_admin_id, v_admin_id)
        ON CONFLICT (code) DO NOTHING;

        INSERT INTO engagement.moderation_status (code, label_key, is_active, sort_order, created_by, updated_by)
        VALUES 
            ('approved', 'engagement.moderation.approved', true, 1, v_admin_id, v_admin_id),
            ('pending_review', 'engagement.moderation.pending_review', true, 2, v_admin_id, v_admin_id),
            ('flagged', 'engagement.moderation.flagged', true, 3, v_admin_id, v_admin_id),
            ('removed', 'engagement.moderation.removed', true, 4, v_admin_id, v_admin_id)
        ON CONFLICT (code) DO NOTHING;

        INSERT INTO engagement.moderation_action_type (code, label_key, is_active, sort_order, created_by, updated_by)
        VALUES 
            ('warn_author', 'engagement.mod_action.warn', true, 1, v_admin_id, v_admin_id),
            ('hide_content', 'engagement.mod_action.hide', true, 2, v_admin_id, v_admin_id),
            ('delete_content', 'engagement.mod_action.delete', true, 3, v_admin_id, v_admin_id),
            ('suspend_author', 'engagement.mod_action.suspend', true, 4, v_admin_id, v_admin_id)
        ON CONFLICT (code) DO NOTHING;

        INSERT INTO engagement.report_reason (code, label_key, is_active, sort_order, created_by, updated_by)
        VALUES 
            ('spam', 'engagement.report.spam', true, 1, v_admin_id, v_admin_id),
            ('harassment', 'engagement.report.harassment', true, 2, v_admin_id, v_admin_id),
            ('inappropriate', 'engagement.report.inappropriate', true, 3, v_admin_id, v_admin_id),
            ('misinformation', 'engagement.report.misinformation', true, 4, v_admin_id, v_admin_id)
        ON CONFLICT (code) DO NOTHING;

        INSERT INTO engagement.review_status (code, label_key, is_active, sort_order, created_by, updated_by)
        VALUES 
            ('unreviewed', 'engagement.review.unreviewed', true, 1, v_admin_id, v_admin_id),
            ('in_progress', 'engagement.review.in_progress', true, 2, v_admin_id, v_admin_id),
            ('dismissed', 'engagement.review.dismissed', true, 3, v_admin_id, v_admin_id),
            ('action_taken', 'engagement.review.action_taken', true, 4, v_admin_id, v_admin_id)
        ON CONFLICT (code) DO NOTHING;

        -- 8. Support Lookups
        INSERT INTO engagement.ticket_category (code, label_key, is_active, sort_order, created_by, updated_by)
        VALUES 
            ('billing_inquiry', 'engagement.ticket.billing', true, 1, v_admin_id, v_admin_id),
            ('account_access', 'engagement.ticket.account', true, 2, v_admin_id, v_admin_id),
            ('technical_bug', 'engagement.ticket.bug', true, 3, v_admin_id, v_admin_id),
            ('data_privacy', 'engagement.ticket.privacy', true, 4, v_admin_id, v_admin_id)
        ON CONFLICT (code) DO NOTHING;

        INSERT INTO engagement.ticket_status (code, label_key, is_active, sort_order, created_by, updated_by)
        VALUES 
            ('open', 'engagement.ticket_status.open', true, 1, v_admin_id, v_admin_id),
            ('in_progress', 'engagement.ticket_status.in_progress', true, 2, v_admin_id, v_admin_id),
            ('waiting_on_customer', 'engagement.ticket_status.waiting', true, 3, v_admin_id, v_admin_id),
            ('resolved', 'engagement.ticket_status.resolved', true, 4, v_admin_id, v_admin_id),
            ('closed', 'engagement.ticket_status.closed', true, 5, v_admin_id, v_admin_id)
        ON CONFLICT (code) DO NOTHING;

        INSERT INTO engagement.ticket_priority (code, label_key, is_active, sort_order, created_by, updated_by)
        VALUES 
            ('low', 'engagement.priority.low', true, 1, v_admin_id, v_admin_id),
            ('normal', 'engagement.priority.normal', true, 2, v_admin_id, v_admin_id),
            ('high', 'engagement.priority.high', true, 3, v_admin_id, v_admin_id),
            ('urgent', 'engagement.priority.urgent', true, 4, v_admin_id, v_admin_id)
        ON CONFLICT (code) DO NOTHING;

        INSERT INTO engagement.faq_category (code, label_key, is_active, sort_order, created_by, updated_by)
        VALUES 
            ('general', 'engagement.faq_cat.general', true, 1, v_admin_id, v_admin_id),
            ('employers', 'engagement.faq_cat.employers', true, 2, v_admin_id, v_admin_id),
            ('candidates', 'engagement.faq_cat.candidates', true, 3, v_admin_id, v_admin_id),
            ('gig_freelancers', 'engagement.faq_cat.gig', true, 4, v_admin_id, v_admin_id)
        ON CONFLICT (code) DO NOTHING;

        -- 9. Referral Lookups
        INSERT INTO engagement.referral_event_type (code, label_key, is_active, sort_order, created_by, updated_by)
        VALUES 
            ('invite_sent', 'engagement.referral.sent', true, 1, v_admin_id, v_admin_id),
            ('signup_completed', 'engagement.referral.signup', true, 2, v_admin_id, v_admin_id),
            ('first_hire_made', 'engagement.referral.hire', true, 3, v_admin_id, v_admin_id)
        ON CONFLICT (code) DO NOTHING;

        INSERT INTO engagement.referral_source_channel (code, label_key, is_active, sort_order, created_by, updated_by)
        VALUES 
            ('direct_link', 'engagement.ref_src.link', true, 1, v_admin_id, v_admin_id),
            ('email_invite', 'engagement.ref_src.email', true, 2, v_admin_id, v_admin_id),
            ('social_share', 'engagement.ref_src.social', true, 3, v_admin_id, v_admin_id)
        ON CONFLICT (code) DO NOTHING;

        -- 10. Sample Notification Template & Translation
        SELECT id INTO v_type_job_alert_id FROM engagement.notification_type WHERE code = 'job_alert';
        SELECT id INTO v_channel_email_id FROM engagement.notification_channel WHERE code = 'email';

        IF v_type_job_alert_id IS NOT NULL AND v_channel_email_id IS NOT NULL THEN
            INSERT INTO engagement.notification_template (
                notification_type_id, notification_channel_id, subject_label_key, is_active, created_by, updated_by
            )
            VALUES (
                v_type_job_alert_id, v_channel_email_id, 'template.job_alert.subject', true, v_admin_id, v_admin_id
            )
            ON CONFLICT (notification_type_id, notification_channel_id) DO NOTHING
            RETURNING id INTO v_template_alert_id;

            IF v_template_alert_id IS NULL THEN
                SELECT id INTO v_template_alert_id FROM engagement.notification_template 
                WHERE notification_type_id = v_type_job_alert_id AND notification_channel_id = v_channel_email_id;
            END IF;

            IF v_template_alert_id IS NOT NULL AND v_lang_en_id IS NOT NULL THEN
                INSERT INTO engagement.notification_template_translation (
                    notification_template_id, language_id, subject_text, body_text, created_by, updated_by
                )
                VALUES (
                    v_template_alert_id, v_lang_en_id, 'New job matches found for your alert: {{alert_name}}',
                    'Hello {{user_name}}, we found {{match_count}} new jobs matching your criteria today.',
                    v_admin_id, v_admin_id
                )
                ON CONFLICT (notification_template_id, language_id) DO NOTHING;
            END IF;
        END IF;

        -- 11. Sample Search Criteria & Job Alert
        SELECT id INTO v_freq_daily_id FROM engagement.alert_frequency WHERE code = 'daily';
        IF v_freq_daily_id IS NOT NULL AND v_channel_email_id IS NOT NULL THEN
            INSERT INTO engagement.search_criteria (
                search_target_code, keyword_text, experience_min_years, experience_max_years, created_by, updated_by
            )
            VALUES ('job', 'PostgreSQL Cloud Architect', 3.0, 10.0, v_admin_id, v_admin_id)
            RETURNING id INTO v_criteria_id;

            IF v_criteria_id IS NOT NULL THEN
                INSERT INTO engagement.job_alert (
                    user_account_id, search_criteria_id, alert_name, alert_frequency_id,
                    notification_channel_id, is_active, created_by, updated_by
                )
                VALUES (
                    v_admin_id, v_criteria_id, 'Senior PostgreSQL Cloud Roles', v_freq_daily_id,
                    v_channel_email_id, true, v_admin_id, v_admin_id
                )
                ON CONFLICT DO NOTHING;
            END IF;
        END IF;

        -- 12. Sample Community Topic & Post
        INSERT INTO engagement.community_topic (topic_label_key, slug, is_active, created_by, updated_by)
        VALUES ('Database Engineering & Scaling', 'database-engineering', true, v_admin_id, v_admin_id)
        ON CONFLICT (slug) DO NOTHING
        RETURNING id INTO v_topic_ai_id;

        IF v_topic_ai_id IS NULL THEN
            SELECT id INTO v_topic_ai_id FROM engagement.community_topic WHERE slug = 'database-engineering';
        END IF;

        SELECT id INTO v_vis_public_id FROM engagement.visibility_level WHERE code = 'public';
        SELECT id INTO v_status_open_id FROM engagement.moderation_status WHERE code = 'approved';

        IF v_vis_public_id IS NOT NULL AND v_status_open_id IS NOT NULL AND v_lang_en_id IS NOT NULL THEN
            INSERT INTO engagement.community_post (
                author_user_account_id, content_text, content_language_id, visibility_level_id,
                moderation_status_id, created_by, updated_by
            )
            VALUES (
                v_admin_id, 'Welcome to the Talentra Developer and Data Engineering Community! Discuss schema designs, query optimizations, and hiring benchmarks here.',
                v_lang_en_id, v_vis_public_id, v_status_open_id, v_admin_id, v_admin_id
            )
            RETURNING id INTO v_post_id;

            IF v_post_id IS NOT NULL AND v_topic_ai_id IS NOT NULL THEN
                INSERT INTO engagement.community_post_topic (community_post_id, community_topic_id)
                VALUES (v_post_id, v_topic_ai_id)
                ON CONFLICT DO NOTHING;
            END IF;
        END IF;

        -- 13. Sample FAQ & Referral Code
        SELECT id INTO v_faq_cat_gen_id FROM engagement.faq_category WHERE code = 'general';
        IF v_faq_cat_gen_id IS NOT NULL AND v_lang_en_id IS NOT NULL THEN
            INSERT INTO engagement.faq (faq_category_id, sort_order, is_published, created_by, updated_by)
            VALUES (v_faq_cat_gen_id, 1, true, v_admin_id, v_admin_id)
            RETURNING id INTO v_faq_id;

            IF v_faq_id IS NOT NULL THEN
                INSERT INTO engagement.faq_translation (
                    faq_id, language_id, question_text, answer_text, created_by, updated_by
                )
                VALUES (
                    v_faq_id, v_lang_en_id, 'How do I download a verified candidate profile?',
                    'Profiles can be viewed and downloaded using either plan quota entitlements or prepaid wallet credits.',
                    v_admin_id, v_admin_id
                )
                ON CONFLICT (faq_id, language_id) DO NOTHING;
            END IF;
        END IF;

        INSERT INTO engagement.referral_code (
            owner_user_account_id, code, usage_limit, usage_count, is_active, created_by, updated_by
        )
        VALUES (
            v_admin_id, 'TAL-WELCOME-2026', 500, 0, true, v_admin_id, v_admin_id
        )
        ON CONFLICT (code) DO NOTHING;
    END IF;
END $$;

COMMIT;
