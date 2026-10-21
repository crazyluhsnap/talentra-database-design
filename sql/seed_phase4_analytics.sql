-- ============================================================================
-- Talentra Enterprise: Phase 4 Module B (Analytics Marts) Seed Data
-- ============================================================================

\set ON_ERROR_STOP on

BEGIN;

-- 1. Populate dim_date calendar (October 2026 dates)
INSERT INTO analytics.dim_date (
    id, calendar_date, calendar_year, calendar_quarter, calendar_month, calendar_week,
    day_of_month, day_of_week, fiscal_year, fiscal_period, is_weekend
)
SELECT 
    (to_char(d, 'YYYYMMDD'))::integer AS id,
    d::date AS calendar_date,
    extract(year FROM d)::smallint AS calendar_year,
    extract(quarter FROM d)::smallint AS calendar_quarter,
    extract(month FROM d)::smallint AS calendar_month,
    extract(week FROM d)::smallint AS calendar_week,
    extract(day FROM d)::smallint AS day_of_month,
    extract(isodow FROM d)::smallint AS day_of_week,
    extract(year FROM d)::smallint AS fiscal_year,
    extract(month FROM d)::smallint AS fiscal_period,
    (extract(isodow FROM d) IN (6, 7)) AS is_weekend
FROM generate_series('2026-10-01'::date, '2026-10-31'::date, '1 day'::interval) d
ON CONFLICT (id) DO NOTHING;

-- 2. Populate dim_currency
INSERT INTO analytics.dim_currency (currency_code, currency_name, minor_units)
VALUES 
    ('USD', 'US Dollar', 2),
    ('INR', 'Indian Rupee', 2),
    ('EUR', 'Euro', 2),
    ('GBP', 'British Pound', 2)
ON CONFLICT (currency_code) DO NOTHING;

-- 3. Populate dim_language
INSERT INTO analytics.dim_language (language_code, language_name)
VALUES 
    ('en', 'English'),
    ('hi', 'Hindi'),
    ('te', 'Telugu'),
    ('ta', 'Tamil'),
    ('es', 'Spanish'),
    ('fr', 'French'),
    ('de', 'German')
ON CONFLICT (language_code) DO NOTHING;

-- 4. Populate dim_job_category (The Eight Mandated Business Categories)
INSERT INTO analytics.dim_job_category (category_code, category_name)
VALUES 
    ('gig', 'Freelance & Milestone Gig Work'),
    ('general_staffing', 'General Commercial Staffing'),
    ('professional_staffing', 'Professional & Lateral Staffing'),
    ('permanent', 'Full-Time Permanent Employment'),
    ('apprentice', 'Apprenticeship & Vocational'),
    ('campus', 'University & Campus Placements'),
    ('consultant_marketplace', 'Independent Consultant Sourcing'),
    ('managed_remote', 'Managed Remote Workforce')
ON CONFLICT (category_code) DO NOTHING;

-- 5. Populate dim_job_status & dim_application_status
INSERT INTO analytics.dim_job_status (status_code, status_group, is_terminal, sort_order)
VALUES 
    ('draft', 'pre_publish', false, 1),
    ('published', 'active', false, 2),
    ('filled', 'terminal', true, 3),
    ('cancelled', 'terminal', true, 4)
ON CONFLICT (status_code) DO NOTHING;

INSERT INTO analytics.dim_application_status (status_code, status_group, outcome_class, is_terminal, sort_order)
VALUES 
    ('applied', 'intake', 'in_progress', false, 1),
    ('screening', 'evaluation', 'in_progress', false, 2),
    ('interviewing', 'evaluation', 'in_progress', false, 3),
    ('offered', 'conversion', 'positive', false, 4),
    ('hired', 'conversion', 'positive', true, 5),
    ('rejected', 'closure', 'negative', true, 6)
ON CONFLICT (status_code) DO NOTHING;

-- 6. Populate dim_channel
INSERT INTO analytics.dim_channel (channel_code, channel_group)
VALUES 
    ('email', 'direct_messaging'),
    ('in_app', 'direct_messaging'),
    ('sms', 'telephony'),
    ('push', 'mobile_os')
ON CONFLICT (channel_code) DO NOTHING;

-- 7. Populate dim_notification_type
INSERT INTO analytics.dim_notification_type (type_code, is_mandatory, type_group)
VALUES 
    ('job_alert', false, 'candidate_discovery'),
    ('security_alert', true, 'platform_security'),
    ('billing_notice', true, 'commercial_contracts'),
    ('application_status', false, 'recruitment_pipeline')
ON CONFLICT (type_code) DO NOTHING;

-- 8. Populate dim_credit_event_type
INSERT INTO analytics.dim_credit_event_type (event_code, event_group)
VALUES 
    ('recharge', 'top_up'),
    ('posting', 'consumption'),
    ('download', 'consumption'),
    ('outreach', 'consumption'),
    ('refund', 'credit_reversal'),
    ('referral_reward', 'promotional_grant')
ON CONFLICT (event_code) DO NOTHING;

-- 9. Populate dim_support_category
INSERT INTO analytics.dim_support_category (category_code, priority_group)
VALUES 
    ('billing_inquiry', 'high'),
    ('account_access', 'critical'),
    ('technical_bug', 'normal'),
    ('data_privacy', 'critical')
ON CONFLICT (category_code) DO NOTHING;

-- 10. Control Tables Initial Fixtures
INSERT INTO analytics.load_watermark (target_table, last_good_window_end)
VALUES 
    ('fact_application_event', '2026-10-21 00:00:00+00'),
    ('fact_payment_transaction', '2026-10-21 00:00:00+00'),
    ('fact_wallet_transaction', '2026-10-21 00:00:00+00')
ON CONFLICT (target_table) DO NOTHING;

COMMIT;
