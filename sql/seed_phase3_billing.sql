-- ============================================================================
-- Talentra Enterprise: Phase 3 Module B (Subscriptions & Wallet) Seed Data
-- ============================================================================

\set ON_ERROR_STOP on

BEGIN;

-- 1. Billing Intervals
INSERT INTO billing.billing_interval (code, name_key, is_active, sort_order)
VALUES 
    ('monthly', 'billing.interval.monthly', true, 1),
    ('quarterly', 'billing.interval.quarterly', true, 2),
    ('annual', 'billing.interval.annual', true, 3)
ON CONFLICT (code) DO NOTHING;

-- 2. Entitlement Reset Periods
INSERT INTO billing.entitlement_reset_period (code, name_key, is_active, sort_order)
VALUES 
    ('none', 'billing.reset.none', true, 1),
    ('daily', 'billing.reset.daily', true, 2),
    ('monthly', 'billing.reset.monthly', true, 3),
    ('per_subscription_period', 'billing.reset.per_subscription_period', true, 4)
ON CONFLICT (code) DO NOTHING;

-- 3. Subscription Status
INSERT INTO billing.subscription_status (code, name_key, is_active, sort_order)
VALUES 
    ('pending', 'billing.sub_status.pending', true, 1),
    ('active', 'billing.sub_status.active', true, 2),
    ('past_due', 'billing.sub_status.past_due', true, 3),
    ('cancelled', 'billing.sub_status.cancelled', true, 4),
    ('expired', 'billing.sub_status.expired', true, 5)
ON CONFLICT (code) DO NOTHING;

-- 4. Subscription Event Type
INSERT INTO billing.subscription_event_type (code, name_key, is_active, sort_order)
VALUES 
    ('created', 'billing.event.created', true, 1),
    ('renewed', 'billing.event.renewed', true, 2),
    ('cancelled', 'billing.event.cancelled', true, 3),
    ('upgraded', 'billing.event.upgraded', true, 4),
    ('downgraded', 'billing.event.downgraded', true, 5),
    ('expired', 'billing.event.expired', true, 6),
    ('payment_failed', 'billing.event.payment_failed', true, 7)
ON CONFLICT (code) DO NOTHING;

-- 5. Order Purpose
INSERT INTO billing.order_purpose (code, name_key, is_active, sort_order)
VALUES 
    ('subscription', 'billing.purpose.subscription', true, 1),
    ('wallet_recharge', 'billing.purpose.wallet_recharge', true, 2)
ON CONFLICT (code) DO NOTHING;

-- 6. Payment Status
INSERT INTO billing.payment_status (code, name_key, is_active, sort_order)
VALUES 
    ('created', 'billing.pay_status.created', true, 1),
    ('pending', 'billing.pay_status.pending', true, 2),
    ('paid', 'billing.pay_status.paid', true, 3),
    ('captured', 'billing.pay_status.captured', true, 4),
    ('failed', 'billing.pay_status.failed', true, 5),
    ('cancelled', 'billing.pay_status.cancelled', true, 6),
    ('refunded', 'billing.pay_status.refunded', true, 7),
    ('partially_refunded', 'billing.pay_status.partially_refunded', true, 8)
ON CONFLICT (code) DO NOTHING;

-- 7. Refund Status
INSERT INTO billing.refund_status (code, name_key, is_active, sort_order)
VALUES 
    ('requested', 'billing.refund_status.requested', true, 1),
    ('completed', 'billing.refund_status.completed', true, 2),
    ('failed', 'billing.refund_status.failed', true, 3)
ON CONFLICT (code) DO NOTHING;

-- 8. Refund Reason
INSERT INTO billing.refund_reason (code, name_key, is_active, sort_order)
VALUES 
    ('duplicate_payment', 'billing.refund_reason.duplicate_payment', true, 1),
    ('service_not_delivered', 'billing.refund_reason.service_not_delivered', true, 2),
    ('customer_request', 'billing.refund_reason.customer_request', true, 3),
    ('fraud', 'billing.refund_reason.fraud', true, 4),
    ('other', 'billing.refund_reason.other', true, 5)
ON CONFLICT (code) DO NOTHING;

-- 9. Invoice Status
INSERT INTO billing.invoice_status (code, name_key, is_active, sort_order)
VALUES 
    ('issued', 'billing.inv_status.issued', true, 1),
    ('void', 'billing.inv_status.void', true, 2)
ON CONFLICT (code) DO NOTHING;

-- 10. Ledger Entry Type
INSERT INTO billing.ledger_entry_type (code, name_key, is_active, sort_order)
VALUES 
    ('recharge', 'billing.ledger.recharge', true, 1),
    ('consume', 'billing.ledger.consume', true, 2),
    ('refund_clawback', 'billing.ledger.refund_clawback', true, 3),
    ('expiry', 'billing.ledger.expiry', true, 4),
    ('adjustment', 'billing.ledger.adjustment', true, 5),
    ('reversal', 'billing.ledger.reversal', true, 6)
ON CONFLICT (code) DO NOTHING;

-- 11. Download Outcome
INSERT INTO billing.download_outcome (code, name_key, is_active, sort_order)
VALUES 
    ('succeeded', 'billing.download.succeeded', true, 1),
    ('denied_blocked', 'billing.download.denied_blocked', true, 2),
    ('denied_no_credit', 'billing.download.denied_no_credit', true, 3),
    ('failed', 'billing.download.failed', true, 4)
ON CONFLICT (code) DO NOTHING;

-- 12. Commercial Plans, Features, Prices & Entitlements
DO $$
DECLARE
    v_admin_id bigint;
    v_int_monthly bigint;
    v_int_annual bigint;
    v_reset_monthly bigint;
    v_usd char(3);
    v_plan_starter_id bigint;
    v_plan_growth_id bigint;
    v_plan_ent_id bigint;
    v_feat_download_id bigint;
    v_feat_outreach_id bigint;
    v_account_id bigint;
    v_licence_id bigint;
    v_sub_status_active_id bigint;
    v_growth_price_id bigint;
    v_sub_id bigint;
    v_wallet_account_id bigint;
    v_ledger_recharge_id bigint;
BEGIN
    SELECT id INTO v_admin_id FROM administration.user_account ORDER BY id LIMIT 1;
    SELECT code INTO v_usd FROM master_data.currency WHERE code = 'USD' LIMIT 1;
    IF v_usd IS NULL THEN SELECT code INTO v_usd FROM master_data.currency ORDER BY code LIMIT 1; END IF;

    SELECT id INTO v_int_monthly FROM billing.billing_interval WHERE code = 'monthly';
    SELECT id INTO v_int_annual FROM billing.billing_interval WHERE code = 'annual';
    SELECT id INTO v_reset_monthly FROM billing.entitlement_reset_period WHERE code = 'monthly';
    SELECT id INTO v_sub_status_active_id FROM billing.subscription_status WHERE code = 'active';
    SELECT id INTO v_ledger_recharge_id FROM billing.ledger_entry_type WHERE code = 'recharge';

    IF v_admin_id IS NOT NULL AND v_int_monthly IS NOT NULL THEN
        -- Insert Plans
        INSERT INTO billing.subscription_plan (code, name_key, billing_interval_id, is_active, created_by, updated_by)
        VALUES 
            ('starter_plan', 'billing.plan.starter', v_int_monthly, true, v_admin_id, v_admin_id),
            ('growth_plan', 'billing.plan.growth', v_int_monthly, true, v_admin_id, v_admin_id),
            ('enterprise_plan', 'billing.plan.enterprise', v_int_annual, true, v_admin_id, v_admin_id)
        ON CONFLICT (code) DO NOTHING;

        SELECT id INTO v_plan_starter_id FROM billing.subscription_plan WHERE code = 'starter_plan';
        SELECT id INTO v_plan_growth_id FROM billing.subscription_plan WHERE code = 'growth_plan';
        SELECT id INTO v_plan_ent_id FROM billing.subscription_plan WHERE code = 'enterprise_plan';

        -- Insert Plan Prices
        IF v_plan_starter_id IS NOT NULL THEN
            INSERT INTO billing.plan_price (subscription_plan_id, amount, currency_code, valid_range, created_by, updated_by)
            VALUES (v_plan_starter_id, 49.00, v_usd, daterange(CURRENT_DATE - 30, NULL), v_admin_id, v_admin_id)
            ON CONFLICT DO NOTHING;
        END IF;

        IF v_plan_growth_id IS NOT NULL THEN
            INSERT INTO billing.plan_price (subscription_plan_id, amount, currency_code, valid_range, created_by, updated_by)
            VALUES (v_plan_growth_id, 199.00, v_usd, daterange(CURRENT_DATE - 30, NULL), v_admin_id, v_admin_id)
            ON CONFLICT DO NOTHING
            RETURNING id INTO v_growth_price_id;

            IF v_growth_price_id IS NULL THEN
                SELECT id INTO v_growth_price_id FROM billing.plan_price WHERE subscription_plan_id = v_plan_growth_id;
            END IF;
        END IF;

        -- Insert Features
        INSERT INTO billing.feature (code, name_key, is_active, created_by, updated_by)
        VALUES 
            ('profile_download', 'billing.feat.profile_download', true, v_admin_id, v_admin_id),
            ('candidate_outreach', 'billing.feat.candidate_outreach', true, v_admin_id, v_admin_id)
        ON CONFLICT (code) DO NOTHING;

        SELECT id INTO v_feat_download_id FROM billing.feature WHERE code = 'profile_download';
        SELECT id INTO v_feat_outreach_id FROM billing.feature WHERE code = 'candidate_outreach';

        -- Insert Plan Entitlements
        IF v_plan_growth_id IS NOT NULL AND v_feat_download_id IS NOT NULL AND v_reset_monthly IS NOT NULL THEN
            INSERT INTO billing.plan_entitlement (subscription_plan_id, feature_id, quota, entitlement_reset_period_id, created_by, updated_by)
            VALUES 
                (v_plan_growth_id, v_feat_download_id, 100, v_reset_monthly, v_admin_id, v_admin_id),
                (v_plan_growth_id, v_feat_outreach_id, 500, v_reset_monthly, v_admin_id, v_admin_id)
            ON CONFLICT (subscription_plan_id, feature_id) DO NOTHING;
        END IF;

        -- Insert Credit Tariffs
        IF v_feat_download_id IS NOT NULL THEN
            INSERT INTO billing.credit_tariff (feature_id, credits_per_unit, valid_range, created_by, updated_by)
            VALUES 
                (v_feat_download_id, 5, daterange(CURRENT_DATE - 30, NULL), v_admin_id, v_admin_id),
                (v_feat_outreach_id, 2, daterange(CURRENT_DATE - 30, NULL), v_admin_id, v_admin_id)
            ON CONFLICT DO NOTHING;
        END IF;

        -- 13. Tenant Subscription & Wallet Fixtures
        SELECT id INTO v_account_id FROM organisation.account WHERE deleted_at IS NULL ORDER BY id LIMIT 1;

        IF v_account_id IS NOT NULL THEN
            -- Ensure Licence exists
            INSERT INTO licence.licence (account_id, licence_key, is_active, created_by, updated_by)
            VALUES (v_account_id, 'LIC-TAL-ENTERPRISE-001', true, v_admin_id, v_admin_id)
            ON CONFLICT (licence_key) DO NOTHING
            RETURNING id INTO v_licence_id;

            IF v_licence_id IS NULL THEN
                SELECT id INTO v_licence_id FROM licence.licence WHERE licence_key = 'LIC-TAL-ENTERPRISE-001';
            END IF;

            -- Create Wallet Account
            INSERT INTO billing.wallet_account (account_id, cached_credit_balance, created_by, updated_by)
            VALUES (v_account_id, 500, v_admin_id, v_admin_id)
            ON CONFLICT (account_id) DO NOTHING
            RETURNING id INTO v_wallet_account_id;

            IF v_wallet_account_id IS NULL THEN
                SELECT id INTO v_wallet_account_id FROM billing.wallet_account WHERE account_id = v_account_id;
            END IF;

            -- Create Initial Credit Ledger Entry
            IF v_wallet_account_id IS NOT NULL AND v_ledger_recharge_id IS NOT NULL THEN
                INSERT INTO billing.wallet_ledger (
                    wallet_account_id, ledger_entry_type_id, credits_signed,
                    balance_after, idempotency_key, note, created_by
                )
                VALUES (
                    v_wallet_account_id, v_ledger_recharge_id, 500,
                    500, 'seed-wallet-init-' || v_account_id, 'Initial Enterprise Platform Credit Grant', v_admin_id
                )
                ON CONFLICT (wallet_account_id, idempotency_key) DO NOTHING;
            END IF;

            -- Create Active Account Subscription Contract
            IF v_licence_id IS NOT NULL AND v_plan_growth_id IS NOT NULL AND v_sub_status_active_id IS NOT NULL THEN
                INSERT INTO billing.account_subscription (
                    account_id, licence_id, subscription_plan_id, subscription_status_id,
                    auto_renew, created_by, updated_by
                )
                VALUES (
                    v_account_id, v_licence_id, v_plan_growth_id, v_sub_status_active_id,
                    true, v_admin_id, v_admin_id
                )
                ON CONFLICT DO NOTHING
                RETURNING id INTO v_sub_id;

                IF v_sub_id IS NULL THEN
                    SELECT id INTO v_sub_id FROM billing.account_subscription 
                    WHERE account_id = v_account_id AND licence_id = v_licence_id;
                END IF;

                -- Create Active Subscription Period
                IF v_sub_id IS NOT NULL AND v_growth_price_id IS NOT NULL THEN
                    INSERT INTO billing.subscription_period (
                        account_subscription_id, licence_id, plan_price_id, valid_range, created_by, updated_by
                    )
                    VALUES (
                        v_sub_id, v_licence_id, v_growth_price_id,
                        tstzrange(CURRENT_TIMESTAMP - interval '10 days', CURRENT_TIMESTAMP + interval '20 days', '[)'),
                        v_admin_id, v_admin_id
                    )
                    ON CONFLICT DO NOTHING;
                END IF;
            END IF;
        END IF;
    END IF;
END $$;

COMMIT;
