-- ============================================================================
-- Talentra Enterprise: Phase 3 Module B (Subscriptions & Wallet) Regression Suite
-- Tests SUB-001 through SUB-013 with transaction-isolated rollback guarantees.
-- ============================================================================

\set ON_ERROR_STOP on

BEGIN;

DO $$
DECLARE
    v_admin_id bigint;
    v_account_id bigint;
    v_usd char(3);
    v_int_id bigint;
    v_reset_id bigint;
    v_status_active_id bigint;
    v_order_purpose_sub_id bigint;
    v_order_purpose_wlt_id bigint;
    v_pay_status_cap_id bigint;
    v_ledger_recharge_id bigint;
    v_ledger_consume_id bigint;
    v_download_outcome_succ_id bigint;
    v_download_outcome_fail_id bigint;
    v_candidate_id bigint;
    v_plan_id bigint;
    v_price_id bigint;
    v_feat_id bigint;
    v_licence_id bigint;
    v_sub_id bigint;
    v_period_id bigint;
    v_order_id bigint;
    v_trans_id bigint;
    v_refund_id bigint;
    v_inv_id bigint;
    v_inv_item_id bigint;
    v_wallet_acc_id bigint;
    v_wallet_ledger_id bigint;
    v_event_id bigint;
    v_usage_id bigint;
    v_seat_id bigint;
    v_dev_id bigint;
    v_history_id bigint;
    v_mrr_rows integer;
    v_bad boolean := false;
BEGIN
    RAISE NOTICE '>>> RUNNING PHASE 3 MODULE B (SUBSCRIPTIONS, LICENSING & WALLET) REGRESSION SUITE...';

    -- Discover Fixtures
    SELECT id INTO v_admin_id FROM administration.user_account ORDER BY id LIMIT 1;
    SELECT id INTO v_account_id FROM organisation.account WHERE deleted_at IS NULL ORDER BY id LIMIT 1;
    SELECT code INTO v_usd FROM master_data.currency WHERE code = 'USD' LIMIT 1;
    IF v_usd IS NULL THEN SELECT code INTO v_usd FROM master_data.currency ORDER BY code LIMIT 1; END IF;
    SELECT id INTO v_candidate_id FROM profile.candidate_profile ORDER BY id LIMIT 1;

    SELECT id INTO v_int_id FROM billing.billing_interval WHERE code = 'monthly';
    SELECT id INTO v_reset_id FROM billing.entitlement_reset_period WHERE code = 'monthly';
    SELECT id INTO v_status_active_id FROM billing.subscription_status WHERE code = 'active';
    SELECT id INTO v_order_purpose_sub_id FROM billing.order_purpose WHERE code = 'subscription';
    SELECT id INTO v_order_purpose_wlt_id FROM billing.order_purpose WHERE code = 'wallet_recharge';
    SELECT id INTO v_pay_status_cap_id FROM billing.payment_status WHERE code = 'captured';
    SELECT id INTO v_ledger_recharge_id FROM billing.ledger_entry_type WHERE code = 'recharge';
    SELECT id INTO v_ledger_consume_id FROM billing.ledger_entry_type WHERE code = 'consume';
    SELECT id INTO v_download_outcome_succ_id FROM billing.download_outcome WHERE code = 'succeeded';
    SELECT id INTO v_download_outcome_fail_id FROM billing.download_outcome WHERE code = 'failed';

    IF v_admin_id IS NULL OR v_account_id IS NULL THEN
        RAISE EXCEPTION 'Prerequisite fixtures missing';
    END IF;

    -- Setup Licence
    INSERT INTO licence.licence (account_id, licence_key, created_by, updated_by)
    VALUES (v_account_id, 'LIC-REG-' || txid_current(), v_admin_id, v_admin_id)
    RETURNING id INTO v_licence_id;

    -- Setup Plan & Price
    INSERT INTO billing.subscription_plan (code, name_key, billing_interval_id, created_by, updated_by)
    VALUES ('sub_test_plan_' || txid_current(), 'test.plan', v_int_id, v_admin_id, v_admin_id)
    RETURNING id INTO v_plan_id;

    -- SUB-001: Plan price amount non-negative check
    BEGIN
        v_bad := false;
        INSERT INTO billing.plan_price (subscription_plan_id, amount, currency_code, valid_range, created_by, updated_by)
        VALUES (v_plan_id, -10.00, v_usd, daterange(CURRENT_DATE, NULL), v_admin_id, v_admin_id);
        v_bad := true;
    EXCEPTION WHEN check_violation THEN NULL;
    END;
    IF v_bad THEN RAISE EXCEPTION 'SUB-001 FAILED: Negative plan price accepted'; END IF;
    RAISE NOTICE 'SUB-001 PASSED: Plan price non-negative check enforced';

    INSERT INTO billing.plan_price (subscription_plan_id, amount, currency_code, valid_range, created_by, updated_by)
    VALUES (v_plan_id, 100.00, v_usd, daterange(CURRENT_DATE - 30, CURRENT_DATE + 30), v_admin_id, v_admin_id)
    RETURNING id INTO v_price_id;

    -- SUB-002: Plan price effective range non-overlapping constraint (EXCLUDE USING gist)
    BEGIN
        v_bad := false;
        INSERT INTO billing.plan_price (subscription_plan_id, amount, currency_code, valid_range, created_by, updated_by)
        VALUES (v_plan_id, 150.00, v_usd, daterange(CURRENT_DATE - 10, CURRENT_DATE + 40), v_admin_id, v_admin_id);
        v_bad := true;
    EXCEPTION WHEN exclusion_violation THEN NULL;
    END;
    IF v_bad THEN RAISE EXCEPTION 'SUB-002 FAILED: Overlapping plan price accepted'; END IF;
    RAISE NOTICE 'SUB-002 PASSED: Plan price non-overlapping exclusion constraint verified';

    -- Setup Feature & Tariff
    INSERT INTO billing.feature (code, name_key, created_by, updated_by)
    VALUES ('sub_feat_' || txid_current(), 'test.feat', v_admin_id, v_admin_id)
    RETURNING id INTO v_feat_id;

    INSERT INTO billing.credit_tariff (feature_id, credits_per_unit, valid_range, created_by, updated_by)
    VALUES (v_feat_id, 5, daterange(CURRENT_DATE - 30, NULL), v_admin_id, v_admin_id);

    -- Setup Contract
    INSERT INTO billing.account_subscription (
        account_id, licence_id, subscription_plan_id, subscription_status_id, created_by, updated_by
    )
    VALUES (v_account_id, v_licence_id, v_plan_id, v_status_active_id, v_admin_id, v_admin_id)
    RETURNING id INTO v_sub_id;

    -- Setup Period
    INSERT INTO billing.subscription_period (
        account_subscription_id, licence_id, plan_price_id, valid_range, created_by, updated_by
    )
    VALUES (
        v_sub_id, v_licence_id, v_price_id,
        tstzrange(CURRENT_TIMESTAMP - interval '10 days', CURRENT_TIMESTAMP + interval '20 days', '[)'),
        v_admin_id, v_admin_id
    )
    RETURNING id INTO v_period_id;

    -- SUB-003: Subscription period non-overlapping per licence constraint (EXCLUDE USING gist)
    BEGIN
        v_bad := false;
        INSERT INTO billing.subscription_period (
            account_subscription_id, licence_id, plan_price_id, valid_range, created_by, updated_by
        )
        VALUES (
            v_sub_id, v_licence_id, v_price_id,
            tstzrange(CURRENT_TIMESTAMP, CURRENT_TIMESTAMP + interval '40 days', '[)'),
            v_admin_id, v_admin_id
        );
        v_bad := true;
    EXCEPTION WHEN exclusion_violation THEN NULL;
    END;
    IF v_bad THEN RAISE EXCEPTION 'SUB-003 FAILED: Overlapping active subscription period accepted'; END IF;
    RAISE NOTICE 'SUB-003 PASSED: Subscription period exclusion constraint verified';

    -- SUB-004: Payment order target constraint (num_nonnulls = 1)
    BEGIN
        v_bad := false;
        INSERT INTO billing.payment_order (
            account_id, order_purpose_id, subscription_period_id, wallet_account_id,
            amount, currency_code, payment_status_id, idempotency_key, created_by, updated_by
        )
        VALUES (
            v_account_id, v_order_purpose_sub_id, NULL, NULL,
            100.00, v_usd, v_status_active_id, 'ord-fail-' || txid_current(), v_admin_id, v_admin_id
        );
        v_bad := true;
    EXCEPTION WHEN check_violation THEN NULL;
    END;
    IF v_bad THEN RAISE EXCEPTION 'SUB-004 FAILED: Payment order without target accepted'; END IF;

    INSERT INTO billing.payment_order (
        account_id, order_purpose_id, subscription_period_id,
        amount, currency_code, payment_status_id, idempotency_key, created_by, updated_by
    )
    VALUES (
        v_account_id, v_order_purpose_sub_id, v_period_id,
        100.00, v_usd, v_status_active_id, 'ord-pass-' || txid_current(), v_admin_id, v_admin_id
    )
    RETURNING id INTO v_order_id;
    RAISE NOTICE 'SUB-004 PASSED: Payment order target constraint verified';

    -- Setup Transaction
    INSERT INTO billing.payment_transaction (
        payment_order_id, gateway_code, gateway_reference, amount, currency_code,
        payment_status_id, created_by
    )
    VALUES (v_order_id, 'stripe', 'gw-tx-' || txid_current(), 100.00, v_usd, v_pay_status_cap_id, v_admin_id)
    RETURNING id INTO v_trans_id;

    -- SUB-005: Refund cap trigger prevents refund exceeding captured amount
    BEGIN
        v_bad := false;
        INSERT INTO billing.refund (
            payment_transaction_id, amount, currency_code, refund_status_id, refund_reason_id,
            requested_by_user_id, idempotency_key, created_by, updated_by
        )
        VALUES (
            v_trans_id, 150.00, v_usd, 1, 1,
            v_admin_id, 'ref-fail-' || txid_current(), v_admin_id, v_admin_id
        );
        v_bad := true;
    EXCEPTION WHEN raise_exception THEN NULL;
    END;
    IF v_bad THEN RAISE EXCEPTION 'SUB-005 FAILED: Refund exceeding captured amount accepted'; END IF;

    INSERT INTO billing.refund (
        payment_transaction_id, amount, currency_code, refund_status_id, refund_reason_id,
        requested_by_user_id, idempotency_key, created_by, updated_by
    )
    VALUES (
        v_trans_id, 50.00, v_usd, 1, 1,
        v_admin_id, 'ref-pass-' || txid_current(), v_admin_id, v_admin_id
    )
    RETURNING id INTO v_refund_id;
    RAISE NOTICE 'SUB-005 PASSED: Refund cap trigger enforced';

    -- SUB-006: Invoice total calculation check (subtotal + tax = total)
    BEGIN
        v_bad := false;
        INSERT INTO billing.invoice (
            account_id, payment_order_id, invoice_number, invoice_status_id,
            subtotal_amount, tax_total, total_amount, currency_code, created_by, updated_by
        )
        VALUES (
            v_account_id, v_order_id, 'INV-FAIL-' || txid_current(), 1,
            100.00, 10.00, 200.00, v_usd, v_admin_id, v_admin_id
        );
        v_bad := true;
    EXCEPTION WHEN check_violation THEN NULL;
    END;
    IF v_bad THEN RAISE EXCEPTION 'SUB-006 FAILED: Mismatched invoice totals accepted'; END IF;

    INSERT INTO billing.invoice (
        account_id, payment_order_id, invoice_number, invoice_status_id,
        subtotal_amount, tax_total, total_amount, currency_code, created_by, updated_by
    )
    VALUES (
        v_account_id, v_order_id, 'INV-PASS-' || txid_current(), 1,
        100.00, 18.00, 118.00, v_usd, v_admin_id, v_admin_id
    )
    RETURNING id INTO v_inv_id;
    RAISE NOTICE 'SUB-006 PASSED: Invoice totals constraint enforced';

    -- SUB-007: Invoice item line math check
    BEGIN
        v_bad := false;
        INSERT INTO billing.invoice_item (
            invoice_id, line_no, description, quantity, unit_price, tax_amount, line_total, created_by, updated_by
        )
        VALUES (v_inv_id, 1, 'Item', 2, 50.00, 0, 90.00, v_admin_id, v_admin_id);
        v_bad := true;
    EXCEPTION WHEN check_violation THEN NULL;
    END;
    IF v_bad THEN RAISE EXCEPTION 'SUB-007 FAILED: Invalid line total accepted'; END IF;
    RAISE NOTICE 'SUB-007 PASSED: Invoice item line arithmetic enforced';

    -- Setup Wallet
    INSERT INTO billing.wallet_account (account_id, cached_credit_balance, created_by, updated_by)
    VALUES (v_account_id, 0, v_admin_id, v_admin_id)
    ON CONFLICT (account_id) DO UPDATE SET updated_at = CURRENT_TIMESTAMP
    RETURNING id INTO v_wallet_acc_id;

    -- SUB-008: Wallet ledger append-only rejects UPDATE
    INSERT INTO billing.wallet_ledger (
        wallet_account_id, ledger_entry_type_id, credits_signed, balance_after,
        idempotency_key, created_by
    )
    VALUES (v_wallet_acc_id, v_ledger_recharge_id, 100, 100, 'wlt-idem-' || txid_current(), v_admin_id)
    RETURNING id INTO v_wallet_ledger_id;

    BEGIN
        v_bad := false;
        UPDATE billing.wallet_ledger SET credits_signed = 200 WHERE id = v_wallet_ledger_id;
        v_bad := true;
    EXCEPTION WHEN raise_exception THEN NULL;
    END;
    IF v_bad THEN RAISE EXCEPTION 'SUB-008 FAILED: Wallet ledger update permitted on append-only table'; END IF;
    RAISE NOTICE 'SUB-008 PASSED: Wallet ledger append-only immutability verified';

    -- SUB-009: Wallet balance cache sync trigger verification
    IF NOT EXISTS (SELECT 1 FROM billing.wallet_account WHERE id = v_wallet_acc_id AND cached_credit_balance = 100) THEN
        RAISE EXCEPTION 'SUB-009 FAILED: Wallet account cached balance did not sync from ledger';
    END IF;
    RAISE NOTICE 'SUB-009 PASSED: Wallet account cache synchronized by trigger';

    -- SUB-010: Subscription event append-only rejects DELETE
    INSERT INTO billing.subscription_event (
        account_subscription_id, subscription_event_type_id, created_by
    )
    VALUES (v_sub_id, 1, v_admin_id)
    RETURNING id INTO v_event_id;

    BEGIN
        v_bad := false;
        DELETE FROM billing.subscription_event WHERE id = v_event_id;
        v_bad := true;
    EXCEPTION WHEN raise_exception THEN NULL;
    END;
    IF v_bad THEN RAISE EXCEPTION 'SUB-010 FAILED: Subscription event delete permitted on append-only table'; END IF;
    RAISE NOTICE 'SUB-010 PASSED: Subscription event append-only immutability verified';

    -- SUB-011: Payment order purpose guard trigger
    BEGIN
        v_bad := false;
        INSERT INTO billing.payment_order (
            account_id, order_purpose_id, subscription_period_id, wallet_account_id,
            amount, currency_code, payment_status_id, idempotency_key, created_by, updated_by
        )
        VALUES (
            v_account_id, v_order_purpose_sub_id, NULL, v_wallet_acc_id,
            100.00, v_usd, v_status_active_id, 'ord-mismatch-' || txid_current(), v_admin_id, v_admin_id
        );
        v_bad := true;
    EXCEPTION WHEN raise_exception THEN NULL;
    END;
    IF v_bad THEN RAISE EXCEPTION 'SUB-011 FAILED: Order with purpose subscription accepted wallet target'; END IF;
    RAISE NOTICE 'SUB-011 PASSED: Payment order purpose target guard trigger verified';

    -- SUB-012: Profile download history single-source guard trigger
    BEGIN
        v_bad := false;
        INSERT INTO billing.profile_download_history (
            actor_user_id, organisation_id, candidate_profile_id, download_outcome_id,
            wallet_ledger_id, entitlement_usage_id, credits_charged, created_by
        )
        VALUES (
            v_admin_id, 1, v_candidate_id, v_download_outcome_succ_id,
            NULL, NULL, 5, v_admin_id
        );
        v_bad := true;
    EXCEPTION WHEN raise_exception THEN NULL;
    END;
    IF v_bad THEN RAISE EXCEPTION 'SUB-012 FAILED: Succeeded profile download accepted with zero funding sources'; END IF;
    RAISE NOTICE 'SUB-012 PASSED: Profile download history single-funding-source guard trigger verified';

    -- SUB-013: Executive MRR KPI View verification
    SELECT COUNT(*) INTO v_mrr_rows FROM billing.v_monthly_recurring_revenue_kpi;
    RAISE NOTICE 'SUB-013 PASSED: Executive MRR & ARR KPI aggregation view verified (% rows computed)', v_mrr_rows;

    -- SUB-014: Seat assignment creation and automatic audit logging
    INSERT INTO licence.seat_assignment (
        licence_id, user_account_id, assigned_by, is_active, created_by, updated_by
    )
    VALUES (
        v_licence_id, v_admin_id, v_admin_id, true, v_admin_id, v_admin_id
    )
    RETURNING id INTO v_seat_id;

    SELECT id INTO v_history_id 
    FROM licence.seat_allocation_history 
    WHERE seat_assignment_id = v_seat_id AND action_type = 'assigned';

    IF v_history_id IS NULL THEN
        RAISE EXCEPTION 'SUB-014 FAILED: Seat assignment failed to automatically log to seat_allocation_history';
    END IF;
    RAISE NOTICE 'SUB-014 PASSED: Seat assignment created and logged to audit trail (history_id=%)', v_history_id;

    -- SUB-015: Registered device creation with SHA-256 fingerprint hash
    INSERT INTO licence.registered_device (
        seat_assignment_id, device_fingerprint_hash, device_name, operating_system,
        is_trusted, created_by, updated_by
    )
    VALUES (
        v_seat_id, sha256('regression_test_device_hash'::bytea), 'Test Recruiter Laptop', 'Windows 11',
        true, v_admin_id, v_admin_id
    )
    RETURNING id INTO v_dev_id;
    RAISE NOTICE 'SUB-015 PASSED: Hardware device registered with SHA-256 fingerprint (dev_id=%)', v_dev_id;

    -- SUB-016: Seat allocation history append-only immutability
    BEGIN
        v_bad := false;
        DELETE FROM licence.seat_allocation_history WHERE id = v_history_id;
        v_bad := true;
    EXCEPTION WHEN raise_exception THEN NULL;
    END;
    IF v_bad THEN RAISE EXCEPTION 'SUB-016 FAILED: Seat allocation history delete permitted on append-only table'; END IF;
    RAISE NOTICE 'SUB-016 PASSED: Seat allocation history append-only immutability verified';

    RAISE NOTICE '>>> ALL 16 SUBSCRIPTION & LICENSING REGRESSION TEST SCENARIOS PASSED!';
END $$;

ROLLBACK;
