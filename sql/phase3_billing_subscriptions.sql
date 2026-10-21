-- ============================================================================
-- Talentra Enterprise Database Architecture
-- Phase 3 - Module B: Subscriptions, Wallet, Payments & Download History (billing)
-- PostgreSQL 16+
--
-- Conforming to: Talentra Phase 3 Improved Schemas Specification (Module B)
--
-- Entities:
-- 1. Licensing & Seat Allocation Subsystem (schema licence):
--    - licence
--    - seat_assignment (Recruiter seat quotas & active constraints)
--    - registered_device (Device fingerprint SHA-256 tokens)
--    - seat_allocation_history (Append-only audit trail)
-- 2. Lookups (Rule Group 3):
--    - billing_interval
--    - entitlement_reset_period
--    - subscription_status
--    - subscription_event_type
--    - order_purpose
--    - payment_status
--    - refund_status
--    - refund_reason
--    - invoice_status
--    - ledger_entry_type
--    - download_outcome
-- 3. Plans, Prices & Entitlements:
--    - subscription_plan
--    - plan_price (Effective-dated with EXCLUDE USING gist)
--    - feature
--    - plan_entitlement
--    - credit_tariff (Effective-dated with EXCLUDE USING gist)
-- 4. Contracts & Quotas:
--    - account_subscription
--    - subscription_period (Non-overlapping with EXCLUDE USING gist)
--    - subscription_event (Append-only)
--    - entitlement_usage (Append-only)
-- 5. Payments, Refunds & Invoices:
--    - payment_method (Tokenized)
--    - payment_order
--    - payment_transaction (Append-only)
--    - payment_gateway_event (Idempotent inbox)
--    - refund
--    - invoice
--    - invoice_item
-- 6. Wallets, Credits & Download History:
--    - wallet_account
--    - wallet_ledger (Append-only)
--    - profile_download_history (Append-only)
--    - outreach_credit_consumption (Append-only)
-- 7. Full B-Tree & GIN Trigram Search Indexes
-- 8. Row-Level Security Policies & Operational/Executive Views
-- ============================================================================

\set ON_ERROR_STOP on

BEGIN;

CREATE EXTENSION IF NOT EXISTS btree_gist;
CREATE EXTENSION IF NOT EXISTS pg_trgm;

CREATE SCHEMA IF NOT EXISTS licence;
CREATE SCHEMA IF NOT EXISTS billing;

-- ============================================================================
-- 1. LICENSING & SEAT ALLOCATION SUBSYSTEM (schema licence)
-- ============================================================================

CREATE TABLE licence.licence (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    account_id bigint NOT NULL REFERENCES organisation.account(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    licence_key varchar(100) NOT NULL,
    max_devices_per_user integer NOT NULL DEFAULT 3,
    is_active boolean NOT NULL DEFAULT true,
    created_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by bigint NOT NULL REFERENCES administration.user_account(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    updated_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by bigint NOT NULL REFERENCES administration.user_account(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    CONSTRAINT uq_licence_key UNIQUE (licence_key),
    CONSTRAINT ck_licence_max_devices CHECK (max_devices_per_user >= 1)
);

CREATE INDEX idx_licence_account_id ON licence.licence(account_id);

CREATE TABLE licence.seat_assignment (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    licence_id bigint NOT NULL REFERENCES licence.licence(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    user_account_id bigint NOT NULL REFERENCES administration.user_account(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    assigned_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    assigned_by bigint NOT NULL REFERENCES administration.user_account(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    is_active boolean NOT NULL DEFAULT true,
    revoked_at timestamptz NULL,
    revoked_by bigint NULL REFERENCES administration.user_account(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    created_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by bigint NOT NULL REFERENCES administration.user_account(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    updated_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by bigint NOT NULL REFERENCES administration.user_account(id) ON UPDATE NO ACTION ON DELETE RESTRICT
);

CREATE UNIQUE INDEX idx_seat_assignment_active_user ON licence.seat_assignment(licence_id, user_account_id) WHERE (is_active = true);
CREATE INDEX idx_seat_assignment_licence_id ON licence.seat_assignment(licence_id);
CREATE INDEX idx_seat_assignment_user_account ON licence.seat_assignment(user_account_id);

CREATE TABLE licence.registered_device (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    seat_assignment_id bigint NOT NULL REFERENCES licence.seat_assignment(id) ON UPDATE NO ACTION ON DELETE CASCADE,
    device_fingerprint_hash bytea NOT NULL,
    device_name varchar(100) NOT NULL,
    operating_system varchar(50) NOT NULL,
    is_trusted boolean NOT NULL DEFAULT true,
    last_seen_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    revoked_at timestamptz NULL,
    created_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by bigint NOT NULL REFERENCES administration.user_account(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    updated_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by bigint NOT NULL REFERENCES administration.user_account(id) ON UPDATE NO ACTION ON DELETE RESTRICT
);

CREATE UNIQUE INDEX idx_registered_device_active_fingerprint ON licence.registered_device(seat_assignment_id, device_fingerprint_hash) WHERE (revoked_at IS NULL);
CREATE INDEX idx_registered_device_seat ON licence.registered_device(seat_assignment_id);

CREATE TABLE licence.seat_allocation_history (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    licence_id bigint NOT NULL REFERENCES licence.licence(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    seat_assignment_id bigint NOT NULL REFERENCES licence.seat_assignment(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    user_account_id bigint NOT NULL REFERENCES administration.user_account(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    action_type varchar(30) NOT NULL,
    actor_user_id bigint NOT NULL REFERENCES administration.user_account(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    reason text NULL,
    created_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_seat_allocation_history_action CHECK (action_type IN ('assigned', 'revoked', 'transferred', 'suspended'))
);

CREATE INDEX idx_seat_history_licence ON licence.seat_allocation_history(licence_id);
CREATE INDEX idx_seat_history_user ON licence.seat_allocation_history(user_account_id);

-- ============================================================================
-- 2. LOOKUP TABLES (Rule Group 3 Standard Pattern)
-- ============================================================================

CREATE TABLE billing.billing_interval (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    code varchar(50) NOT NULL,
    name_key varchar(150) NOT NULL,
    is_active boolean NOT NULL DEFAULT true,
    sort_order integer NOT NULL,
    CONSTRAINT uq_billing_interval_code UNIQUE (code),
    CONSTRAINT chk_billing_interval_code CHECK (code ~ '^[a-z][a-z0-9_]*$')
);

CREATE TABLE billing.entitlement_reset_period (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    code varchar(50) NOT NULL,
    name_key varchar(150) NOT NULL,
    is_active boolean NOT NULL DEFAULT true,
    sort_order integer NOT NULL,
    CONSTRAINT uq_entitlement_reset_period_code UNIQUE (code),
    CONSTRAINT chk_entitlement_reset_period_code CHECK (code ~ '^[a-z][a-z0-9_]*$')
);

CREATE TABLE billing.subscription_status (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    code varchar(50) NOT NULL,
    name_key varchar(150) NOT NULL,
    is_active boolean NOT NULL DEFAULT true,
    sort_order integer NOT NULL,
    CONSTRAINT uq_billing_subscription_status_code UNIQUE (code),
    CONSTRAINT chk_billing_subscription_status_code CHECK (code ~ '^[a-z][a-z0-9_]*$')
);

CREATE TABLE billing.subscription_event_type (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    code varchar(50) NOT NULL,
    name_key varchar(150) NOT NULL,
    is_active boolean NOT NULL DEFAULT true,
    sort_order integer NOT NULL,
    CONSTRAINT uq_subscription_event_type_code UNIQUE (code),
    CONSTRAINT chk_subscription_event_type_code CHECK (code ~ '^[a-z][a-z0-9_]*$')
);

CREATE TABLE billing.order_purpose (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    code varchar(50) NOT NULL,
    name_key varchar(150) NOT NULL,
    is_active boolean NOT NULL DEFAULT true,
    sort_order integer NOT NULL,
    CONSTRAINT uq_order_purpose_code UNIQUE (code),
    CONSTRAINT chk_order_purpose_code CHECK (code ~ '^[a-z][a-z0-9_]*$')
);

CREATE TABLE billing.payment_status (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    code varchar(50) NOT NULL,
    name_key varchar(150) NOT NULL,
    is_active boolean NOT NULL DEFAULT true,
    sort_order integer NOT NULL,
    CONSTRAINT uq_billing_payment_status_code UNIQUE (code),
    CONSTRAINT chk_billing_payment_status_code CHECK (code ~ '^[a-z][a-z0-9_]*$')
);

CREATE TABLE billing.refund_status (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    code varchar(50) NOT NULL,
    name_key varchar(150) NOT NULL,
    is_active boolean NOT NULL DEFAULT true,
    sort_order integer NOT NULL,
    CONSTRAINT uq_refund_status_code UNIQUE (code),
    CONSTRAINT chk_refund_status_code CHECK (code ~ '^[a-z][a-z0-9_]*$')
);

CREATE TABLE billing.refund_reason (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    code varchar(50) NOT NULL,
    name_key varchar(150) NOT NULL,
    is_active boolean NOT NULL DEFAULT true,
    sort_order integer NOT NULL,
    CONSTRAINT uq_refund_reason_code UNIQUE (code),
    CONSTRAINT chk_refund_reason_code CHECK (code ~ '^[a-z][a-z0-9_]*$')
);

CREATE TABLE billing.invoice_status (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    code varchar(50) NOT NULL,
    name_key varchar(150) NOT NULL,
    is_active boolean NOT NULL DEFAULT true,
    sort_order integer NOT NULL,
    CONSTRAINT uq_billing_invoice_status_code UNIQUE (code),
    CONSTRAINT chk_billing_invoice_status_code CHECK (code ~ '^[a-z][a-z0-9_]*$')
);

CREATE TABLE billing.ledger_entry_type (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    code varchar(50) NOT NULL,
    name_key varchar(150) NOT NULL,
    is_active boolean NOT NULL DEFAULT true,
    sort_order integer NOT NULL,
    CONSTRAINT uq_ledger_entry_type_code UNIQUE (code),
    CONSTRAINT chk_ledger_entry_type_code CHECK (code ~ '^[a-z][a-z0-9_]*$')
);

CREATE TABLE billing.download_outcome (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    code varchar(50) NOT NULL,
    name_key varchar(150) NOT NULL,
    is_active boolean NOT NULL DEFAULT true,
    sort_order integer NOT NULL,
    CONSTRAINT uq_download_outcome_code UNIQUE (code),
    CONSTRAINT chk_download_outcome_code CHECK (code ~ '^[a-z][a-z0-9_]*$')
);

-- ============================================================================
-- 3. PLANS, PRICES & ENTITLEMENTS
-- ============================================================================

CREATE TABLE billing.subscription_plan (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    code varchar(50) NOT NULL,
    name_key varchar(100) NOT NULL,
    billing_interval_id bigint NOT NULL REFERENCES billing.billing_interval(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    is_active boolean NOT NULL DEFAULT true,
    deleted_at timestamptz NULL,
    created_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by bigint NOT NULL REFERENCES administration.user_account(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    updated_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by bigint NOT NULL REFERENCES administration.user_account(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    CONSTRAINT uq_subscription_plan_code UNIQUE (code),
    CONSTRAINT chk_subscription_plan_code CHECK (code ~ '^[a-z][a-z0-9_]*$')
);

CREATE INDEX idx_subscription_plan_billing_interval ON billing.subscription_plan(billing_interval_id);

CREATE TABLE billing.plan_price (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    subscription_plan_id bigint NOT NULL REFERENCES billing.subscription_plan(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    amount numeric(14,2) NOT NULL,
    currency_code char(3) NOT NULL REFERENCES master_data.currency(code) ON UPDATE NO ACTION ON DELETE RESTRICT,
    valid_range daterange NOT NULL,
    created_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by bigint NOT NULL REFERENCES administration.user_account(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    updated_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by bigint NOT NULL REFERENCES administration.user_account(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    CONSTRAINT ck_plan_price_amount CHECK (amount >= 0),
    CONSTRAINT ck_plan_price_range CHECK (NOT isempty(valid_range) AND NOT lower_inf(valid_range)),
    CONSTRAINT ex_plan_price_range EXCLUDE USING gist (
        subscription_plan_id WITH =,
        currency_code WITH =,
        valid_range WITH &&
    )
);

CREATE INDEX idx_plan_price_subscription_plan_id ON billing.plan_price(subscription_plan_id);
CREATE INDEX idx_plan_price_currency_code ON billing.plan_price(currency_code);

CREATE TABLE billing.feature (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    code varchar(50) NOT NULL,
    name_key varchar(100) NOT NULL,
    is_active boolean NOT NULL DEFAULT true,
    deleted_at timestamptz NULL,
    created_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by bigint NOT NULL REFERENCES administration.user_account(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    updated_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by bigint NOT NULL REFERENCES administration.user_account(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    CONSTRAINT uq_feature_code UNIQUE (code),
    CONSTRAINT chk_feature_code CHECK (code ~ '^[a-z][a-z0-9_]*$')
);

CREATE TABLE billing.plan_entitlement (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    subscription_plan_id bigint NOT NULL REFERENCES billing.subscription_plan(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    feature_id bigint NOT NULL REFERENCES billing.feature(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    quota integer NULL,
    entitlement_reset_period_id bigint NOT NULL REFERENCES billing.entitlement_reset_period(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    created_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by bigint NOT NULL REFERENCES administration.user_account(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    updated_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by bigint NOT NULL REFERENCES administration.user_account(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    CONSTRAINT uq_plan_entitlement_plan_feature UNIQUE (subscription_plan_id, feature_id),
    CONSTRAINT ck_plan_entitlement_quota CHECK (quota IS NULL OR quota >= 0)
);

CREATE INDEX idx_plan_entitlement_feature_id ON billing.plan_entitlement(feature_id);
CREATE INDEX idx_plan_entitlement_reset_period ON billing.plan_entitlement(entitlement_reset_period_id);

CREATE TABLE billing.credit_tariff (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    feature_id bigint NOT NULL REFERENCES billing.feature(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    credits_per_unit integer NOT NULL,
    valid_range daterange NOT NULL,
    created_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by bigint NOT NULL REFERENCES administration.user_account(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    updated_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by bigint NOT NULL REFERENCES administration.user_account(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    CONSTRAINT ck_credit_tariff_credits CHECK (credits_per_unit > 0),
    CONSTRAINT ex_credit_tariff_range EXCLUDE USING gist (
        feature_id WITH =,
        valid_range WITH &&
    )
);

CREATE INDEX idx_credit_tariff_feature_id ON billing.credit_tariff(feature_id);

-- ============================================================================
-- 4. CONTRACTS, SUBSCRIPTION PERIODS & QUOTA CONSUMPTION
-- ============================================================================

CREATE TABLE billing.account_subscription (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    account_id bigint NOT NULL REFERENCES organisation.account(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    licence_id bigint NOT NULL REFERENCES licence.licence(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    subscription_plan_id bigint NOT NULL REFERENCES billing.subscription_plan(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    subscription_status_id bigint NOT NULL REFERENCES billing.subscription_status(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    auto_renew boolean NOT NULL DEFAULT true,
    cancelled_at timestamptz NULL,
    created_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by bigint NOT NULL REFERENCES administration.user_account(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    updated_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by bigint NOT NULL REFERENCES administration.user_account(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    CONSTRAINT uq_account_subscription_id_licence_id UNIQUE (id, licence_id)
);

CREATE INDEX idx_account_subscription_account_id ON billing.account_subscription(account_id);
CREATE INDEX idx_account_subscription_licence_id ON billing.account_subscription(licence_id);
CREATE INDEX idx_account_subscription_plan_id ON billing.account_subscription(subscription_plan_id);
CREATE INDEX idx_account_subscription_status_id ON billing.account_subscription(subscription_status_id);

CREATE TABLE billing.subscription_period (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    account_subscription_id bigint NOT NULL,
    licence_id bigint NOT NULL,
    plan_price_id bigint NOT NULL REFERENCES billing.plan_price(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    valid_range tstzrange NOT NULL,
    renewal_of_period_id bigint NULL REFERENCES billing.subscription_period(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    cancelled_at timestamptz NULL,
    created_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by bigint NOT NULL REFERENCES administration.user_account(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    updated_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by bigint NOT NULL REFERENCES administration.user_account(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    CONSTRAINT fk_subscription_period_account_subscription 
        FOREIGN KEY (account_subscription_id, licence_id)
        REFERENCES billing.account_subscription(id, licence_id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    CONSTRAINT ck_subscription_period_range CHECK (
        NOT isempty(valid_range) AND NOT lower_inf(valid_range) AND NOT upper_inf(valid_range)
    ),
    CONSTRAINT ex_subscription_period_range EXCLUDE USING gist (
        licence_id WITH =,
        valid_range WITH &&
    ) WHERE (cancelled_at IS NULL)
);

CREATE INDEX idx_subscription_period_account_subscription_id ON billing.subscription_period(account_subscription_id);
CREATE INDEX idx_subscription_period_plan_price_id ON billing.subscription_period(plan_price_id);
CREATE INDEX idx_subscription_period_renewal_of ON billing.subscription_period(renewal_of_period_id);

-- Append-only history of renewals, cancellations and plan changes
CREATE TABLE billing.subscription_event (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    account_subscription_id bigint NOT NULL REFERENCES billing.account_subscription(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    subscription_period_id bigint NULL REFERENCES billing.subscription_period(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    subscription_event_type_id bigint NOT NULL REFERENCES billing.subscription_event_type(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    occurred_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    actor_user_id bigint NULL REFERENCES administration.user_account(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    created_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by bigint NOT NULL REFERENCES administration.user_account(id) ON UPDATE NO ACTION ON DELETE RESTRICT
);

CREATE INDEX idx_subscription_event_account_subscription_id 
ON billing.subscription_event(account_subscription_id, occurred_at DESC);
CREATE INDEX idx_subscription_event_type_id ON billing.subscription_event(subscription_event_type_id);

-- Consumption of a plan quota (Append-only)
CREATE TABLE billing.entitlement_usage (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    subscription_period_id bigint NOT NULL REFERENCES billing.subscription_period(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    feature_id bigint NOT NULL REFERENCES billing.feature(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    quantity integer NOT NULL,
    actor_user_id bigint NOT NULL REFERENCES administration.user_account(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    used_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    idempotency_key varchar(64) NOT NULL,
    created_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by bigint NOT NULL REFERENCES administration.user_account(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    CONSTRAINT ck_entitlement_usage_quantity CHECK (quantity > 0),
    CONSTRAINT uq_entitlement_usage_idempotency_key UNIQUE (idempotency_key)
);

CREATE INDEX idx_entitlement_usage_period_feature 
ON billing.entitlement_usage(subscription_period_id, feature_id, used_at);
CREATE INDEX idx_entitlement_usage_actor ON billing.entitlement_usage(actor_user_id);

-- ============================================================================
-- 5. WALLET ACCOUNTS & IMMUTABLE LEDGER
-- ============================================================================

CREATE TABLE billing.wallet_account (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    account_id bigint NOT NULL REFERENCES organisation.account(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    cached_credit_balance bigint NOT NULL DEFAULT 0,
    last_reconciled_at timestamptz NULL,
    created_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by bigint NOT NULL REFERENCES administration.user_account(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    updated_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by bigint NOT NULL REFERENCES administration.user_account(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    CONSTRAINT uq_wallet_account_account_id UNIQUE (account_id),
    CONSTRAINT ck_wallet_account_balance CHECK (cached_credit_balance >= 0)
);

CREATE TABLE billing.wallet_ledger (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    wallet_account_id bigint NOT NULL REFERENCES billing.wallet_account(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    ledger_entry_type_id bigint NOT NULL REFERENCES billing.ledger_entry_type(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    credits_signed bigint NOT NULL,
    balance_after bigint NOT NULL,
    payment_transaction_id bigint NULL,
    refund_id bigint NULL,
    reversal_of_wallet_ledger_id bigint NULL REFERENCES billing.wallet_ledger(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    idempotency_key varchar(64) NOT NULL,
    occurred_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    note varchar(300) NULL,
    created_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by bigint NOT NULL REFERENCES administration.user_account(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    CONSTRAINT ck_wallet_ledger_amount CHECK (credits_signed <> 0 AND balance_after >= 0),
    CONSTRAINT ck_wallet_ledger_source CHECK (
        num_nonnulls(payment_transaction_id, refund_id, reversal_of_wallet_ledger_id) <= 1
    ),
    CONSTRAINT uq_wallet_ledger_idempotency_key UNIQUE (wallet_account_id, idempotency_key),
    CONSTRAINT uq_wallet_ledger_payment_transaction_id UNIQUE (payment_transaction_id),
    CONSTRAINT uq_wallet_ledger_refund_id UNIQUE (refund_id),
    CONSTRAINT uq_wallet_ledger_reversal_of UNIQUE (reversal_of_wallet_ledger_id)
);

CREATE INDEX idx_wallet_ledger_wallet_account_id 
ON billing.wallet_ledger(wallet_account_id, occurred_at DESC);
CREATE INDEX idx_wallet_ledger_entry_type ON billing.wallet_ledger(ledger_entry_type_id);

-- ============================================================================
-- 6. PAYMENTS, GATEWAY INBOX, REFUNDS & INVOICES
-- ============================================================================

CREATE TABLE billing.payment_method (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    account_id bigint NOT NULL REFERENCES organisation.account(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    gateway_code varchar(30) NOT NULL,
    provider_token varchar(255) NOT NULL,
    brand_code varchar(30) NULL,
    last4_masked char(4) NULL,
    is_default boolean NOT NULL DEFAULT false,
    deleted_at timestamptz NULL,
    created_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by bigint NOT NULL REFERENCES administration.user_account(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    updated_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by bigint NOT NULL REFERENCES administration.user_account(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    CONSTRAINT uq_payment_method_gateway_token UNIQUE (gateway_code, provider_token)
);

CREATE UNIQUE INDEX uq_payment_method_default 
ON billing.payment_method(account_id) 
WHERE is_default AND deleted_at IS NULL;

CREATE INDEX idx_payment_method_account_id ON billing.payment_method(account_id);

CREATE TABLE billing.payment_order (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    account_id bigint NOT NULL REFERENCES organisation.account(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    order_purpose_id bigint NOT NULL REFERENCES billing.order_purpose(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    subscription_period_id bigint NULL REFERENCES billing.subscription_period(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    wallet_account_id bigint NULL REFERENCES billing.wallet_account(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    credits_to_grant bigint NULL,
    payment_method_id bigint NULL REFERENCES billing.payment_method(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    amount numeric(14,2) NOT NULL,
    currency_code char(3) NOT NULL REFERENCES master_data.currency(code) ON UPDATE NO ACTION ON DELETE RESTRICT,
    payment_status_id bigint NOT NULL REFERENCES billing.payment_status(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    idempotency_key varchar(64) NOT NULL,
    created_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by bigint NOT NULL REFERENCES administration.user_account(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    updated_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by bigint NOT NULL REFERENCES administration.user_account(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    CONSTRAINT ck_payment_order_target CHECK (num_nonnulls(subscription_period_id, wallet_account_id) = 1),
    CONSTRAINT ck_payment_order_amount CHECK (amount > 0),
    CONSTRAINT ck_payment_order_credits CHECK (credits_to_grant IS NULL OR credits_to_grant > 0),
    CONSTRAINT uq_payment_order_idempotency_key UNIQUE (account_id, idempotency_key)
);

CREATE INDEX idx_payment_order_account_id ON billing.payment_order(account_id);
CREATE INDEX idx_payment_order_payment_status_id ON billing.payment_order(payment_status_id);
CREATE INDEX idx_payment_order_order_purpose_id ON billing.payment_order(order_purpose_id);
CREATE INDEX idx_payment_order_subscription_period_id ON billing.payment_order(subscription_period_id);
CREATE INDEX idx_payment_order_wallet_account_id ON billing.payment_order(wallet_account_id);
CREATE INDEX idx_payment_order_payment_method_id ON billing.payment_order(payment_method_id);

CREATE TABLE billing.payment_transaction (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    payment_order_id bigint NOT NULL REFERENCES billing.payment_order(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    gateway_code varchar(30) NOT NULL,
    gateway_reference varchar(100) NOT NULL,
    amount numeric(14,2) NOT NULL,
    currency_code char(3) NOT NULL REFERENCES master_data.currency(code) ON UPDATE NO ACTION ON DELETE RESTRICT,
    payment_status_id bigint NOT NULL REFERENCES billing.payment_status(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    failure_code varchar(50) NULL,
    occurred_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by bigint NOT NULL REFERENCES administration.user_account(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    CONSTRAINT uq_payment_transaction_gateway_reference UNIQUE (gateway_code, gateway_reference),
    CONSTRAINT uq_payment_transaction_id_currency_code UNIQUE (id, currency_code),
    CONSTRAINT ck_payment_transaction_amount CHECK (amount > 0)
);

CREATE INDEX idx_payment_transaction_payment_order_id ON billing.payment_transaction(payment_order_id);
CREATE INDEX idx_payment_transaction_payment_status_id ON billing.payment_transaction(payment_status_id);

ALTER TABLE billing.wallet_ledger
ADD CONSTRAINT fk_wallet_ledger_payment_transaction
FOREIGN KEY (payment_transaction_id) REFERENCES billing.payment_transaction(id)
ON UPDATE NO ACTION ON DELETE RESTRICT;

CREATE TABLE billing.payment_gateway_event (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    gateway_code varchar(30) NOT NULL,
    external_event_id varchar(100) NOT NULL,
    event_type varchar(60) NOT NULL,
    payload_hash char(64) NOT NULL,
    received_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    processed_at timestamptz NULL,
    payment_transaction_id bigint NULL REFERENCES billing.payment_transaction(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    created_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by bigint NOT NULL REFERENCES administration.user_account(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    CONSTRAINT uq_payment_gateway_event_external UNIQUE (gateway_code, external_event_id)
);

CREATE INDEX idx_payment_gateway_event_processed_at 
ON billing.payment_gateway_event(processed_at) 
WHERE processed_at IS NULL;

CREATE TABLE billing.refund (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    payment_transaction_id bigint NOT NULL,
    amount numeric(14,2) NOT NULL,
    currency_code char(3) NOT NULL,
    refund_status_id bigint NOT NULL REFERENCES billing.refund_status(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    refund_reason_id bigint NOT NULL REFERENCES billing.refund_reason(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    gateway_reference varchar(100) NULL,
    requested_by_user_id bigint NOT NULL REFERENCES administration.user_account(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    requested_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    completed_at timestamptz NULL,
    idempotency_key varchar(64) NOT NULL,
    created_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by bigint NOT NULL REFERENCES administration.user_account(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    updated_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by bigint NOT NULL REFERENCES administration.user_account(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    CONSTRAINT fk_refund_payment_transaction FOREIGN KEY (payment_transaction_id, currency_code)
        REFERENCES billing.payment_transaction(id, currency_code) ON UPDATE NO ACTION ON DELETE RESTRICT,
    CONSTRAINT ck_refund_amount CHECK (amount > 0),
    CONSTRAINT ck_refund_completed CHECK (completed_at IS NULL OR completed_at >= requested_at),
    CONSTRAINT uq_refund_idempotency_key UNIQUE (idempotency_key)
);

CREATE UNIQUE INDEX uq_refund_gateway_reference 
ON billing.refund(gateway_reference) 
WHERE gateway_reference IS NOT NULL;

CREATE INDEX idx_refund_payment_transaction ON billing.refund(payment_transaction_id);
CREATE INDEX idx_refund_status_id ON billing.refund(refund_status_id);
CREATE INDEX idx_refund_reason_id ON billing.refund(refund_reason_id);

ALTER TABLE billing.wallet_ledger
ADD CONSTRAINT fk_wallet_ledger_refund
FOREIGN KEY (refund_id) REFERENCES billing.refund(id)
ON UPDATE NO ACTION ON DELETE RESTRICT;

CREATE TABLE billing.invoice (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    account_id bigint NOT NULL REFERENCES organisation.account(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    payment_order_id bigint NOT NULL REFERENCES billing.payment_order(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    invoice_number varchar(40) NOT NULL,
    invoice_status_id bigint NOT NULL REFERENCES billing.invoice_status(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    issued_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    subtotal_amount numeric(14,2) NOT NULL,
    tax_total numeric(14,2) NOT NULL,
    total_amount numeric(14,2) NOT NULL,
    currency_code char(3) NOT NULL REFERENCES master_data.currency(code) ON UPDATE NO ACTION ON DELETE RESTRICT,
    buyer_tax_id varchar(50) NULL,
    buyer_tax_id_type_code varchar(20) NULL,
    buyer_tax_country_code char(2) NULL,
    created_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by bigint NOT NULL REFERENCES administration.user_account(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    updated_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by bigint NOT NULL REFERENCES administration.user_account(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    CONSTRAINT uq_invoice_invoice_number UNIQUE (invoice_number),
    CONSTRAINT ck_invoice_totals CHECK (
        subtotal_amount >= 0 AND tax_total >= 0 AND total_amount = subtotal_amount + tax_total
    ),
    CONSTRAINT ck_invoice_tax_id CHECK (
        (buyer_tax_id IS NULL) = (buyer_tax_id_type_code IS NULL) AND
        (buyer_tax_id IS NULL) = (buyer_tax_country_code IS NULL)
    )
);

CREATE INDEX idx_invoice_account_id ON billing.invoice(account_id);
CREATE INDEX idx_invoice_payment_order_id ON billing.invoice(payment_order_id);
CREATE INDEX idx_invoice_status_id ON billing.invoice(invoice_status_id);

CREATE TABLE billing.invoice_item (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    invoice_id bigint NOT NULL REFERENCES billing.invoice(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    line_no smallint NOT NULL,
    description varchar(300) NOT NULL,
    quantity numeric(10,2) NOT NULL,
    unit_price numeric(14,2) NOT NULL,
    tax_amount numeric(14,2) NOT NULL,
    line_total numeric(14,2) NOT NULL,
    created_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by bigint NOT NULL REFERENCES administration.user_account(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    updated_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by bigint NOT NULL REFERENCES administration.user_account(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    CONSTRAINT uq_invoice_item_invoice_line UNIQUE (invoice_id, line_no),
    CONSTRAINT ck_invoice_item_amounts CHECK (
        quantity > 0 AND unit_price >= 0 AND tax_amount >= 0 AND line_total = round(quantity * unit_price + tax_amount, 2)
    )
);

-- ============================================================================
-- 7. USAGE TRACKING: PROFILE DOWNLOADS & OUTREACH CREDIT CONSUMPTION
-- ============================================================================

CREATE TABLE billing.profile_download_history (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    actor_user_id bigint NOT NULL REFERENCES administration.user_account(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    organisation_id bigint NOT NULL REFERENCES organisation.organisation(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    candidate_profile_id bigint NOT NULL REFERENCES profile.candidate_profile(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    downloaded_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    download_outcome_id bigint NOT NULL REFERENCES billing.download_outcome(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    wallet_ledger_id bigint NULL REFERENCES billing.wallet_ledger(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    entitlement_usage_id bigint NULL REFERENCES billing.entitlement_usage(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    credit_tariff_id bigint NULL REFERENCES billing.credit_tariff(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    credits_charged bigint NOT NULL DEFAULT 0,
    created_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by bigint NOT NULL REFERENCES administration.user_account(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    CONSTRAINT ck_profile_download_history_source CHECK (
        num_nonnulls(wallet_ledger_id, entitlement_usage_id) <= 1 AND credits_charged >= 0
    )
);

CREATE UNIQUE INDEX uq_profile_download_history_wallet_ledger_id 
ON billing.profile_download_history(wallet_ledger_id) 
WHERE wallet_ledger_id IS NOT NULL;

CREATE UNIQUE INDEX uq_profile_download_history_entitlement_usage_id 
ON billing.profile_download_history(entitlement_usage_id) 
WHERE entitlement_usage_id IS NOT NULL;

CREATE INDEX idx_profile_download_history_candidate_profile_id 
ON billing.profile_download_history(candidate_profile_id, downloaded_at DESC);

CREATE INDEX idx_profile_download_history_organisation_id 
ON billing.profile_download_history(organisation_id);

CREATE INDEX idx_profile_download_history_actor ON billing.profile_download_history(actor_user_id);
CREATE INDEX idx_profile_download_history_outcome ON billing.profile_download_history(download_outcome_id);

CREATE TABLE billing.outreach_credit_consumption (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    outreach_recipient_id bigint NOT NULL REFERENCES sourcing.outreach_recipient(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    wallet_ledger_id bigint NOT NULL REFERENCES billing.wallet_ledger(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    credit_tariff_id bigint NOT NULL REFERENCES billing.credit_tariff(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    credits_charged bigint NOT NULL,
    created_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by bigint NOT NULL REFERENCES administration.user_account(id) ON UPDATE NO ACTION ON DELETE RESTRICT,
    CONSTRAINT uq_outreach_credit_consumption_outreach_recipient_id UNIQUE (outreach_recipient_id),
    CONSTRAINT ck_outreach_credit_consumption_credits CHECK (credits_charged > 0)
);

CREATE INDEX idx_outreach_credit_consumption_wallet_ledger_id 
ON billing.outreach_credit_consumption(wallet_ledger_id);
CREATE INDEX idx_outreach_credit_consumption_tariff ON billing.outreach_credit_consumption(credit_tariff_id);

-- Wire Phase 2 gig_request seam into billing.wallet_ledger
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'gig' AND table_name = 'gig_request' AND column_name = 'credit_ledger_entry_id'
    ) THEN
        IF NOT EXISTS (
            SELECT 1 FROM information_schema.table_constraints 
            WHERE constraint_schema = 'gig' AND constraint_name = 'fk_gig_request_credit_ledger'
        ) THEN
            ALTER TABLE gig.gig_request 
            ADD CONSTRAINT fk_gig_request_credit_ledger 
            FOREIGN KEY (credit_ledger_entry_id) 
            REFERENCES billing.wallet_ledger(id) 
            ON UPDATE NO ACTION ON DELETE RESTRICT;
        END IF;
    END IF;
END $$;

-- ============================================================================
-- 8. AUTOMATED TRIGGERS & ENFORCEMENT DESIGN (Section 4.6 B47)
-- ============================================================================

-- A. Append-only enforcement on ledgers and audit streams
CREATE TRIGGER trg_wallet_ledger_append_only
BEFORE UPDATE OR DELETE ON billing.wallet_ledger
FOR EACH ROW EXECUTE FUNCTION enforce_append_only();

CREATE TRIGGER trg_subscription_event_append_only
BEFORE UPDATE OR DELETE ON billing.subscription_event
FOR EACH ROW EXECUTE FUNCTION enforce_append_only();

CREATE TRIGGER trg_entitlement_usage_append_only
BEFORE UPDATE OR DELETE ON billing.entitlement_usage
FOR EACH ROW EXECUTE FUNCTION enforce_append_only();

CREATE TRIGGER trg_payment_transaction_append_only
BEFORE UPDATE OR DELETE ON billing.payment_transaction
FOR EACH ROW EXECUTE FUNCTION enforce_append_only();

CREATE TRIGGER trg_profile_download_history_append_only
BEFORE UPDATE OR DELETE ON billing.profile_download_history
FOR EACH ROW EXECUTE FUNCTION enforce_append_only();

CREATE TRIGGER trg_outreach_credit_consumption_append_only
BEFORE UPDATE OR DELETE ON billing.outreach_credit_consumption
FOR EACH ROW EXECUTE FUNCTION enforce_append_only();

CREATE TRIGGER trg_seat_allocation_history_append_only
BEFORE UPDATE OR DELETE ON licence.seat_allocation_history
FOR EACH ROW EXECUTE FUNCTION enforce_append_only();

-- B. Updated_at maintenance triggers
CREATE TRIGGER trg_licence_licence_updated_at
BEFORE UPDATE ON licence.licence
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_seat_assignment_updated_at
BEFORE UPDATE ON licence.seat_assignment
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_registered_device_updated_at
BEFORE UPDATE ON licence.registered_device
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_billing_subscription_plan_updated_at
BEFORE UPDATE ON billing.subscription_plan
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_plan_price_updated_at
BEFORE UPDATE ON billing.plan_price
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_billing_feature_updated_at
BEFORE UPDATE ON billing.feature
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_billing_plan_entitlement_updated_at
BEFORE UPDATE ON billing.plan_entitlement
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_credit_tariff_updated_at
BEFORE UPDATE ON billing.credit_tariff
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_billing_account_subscription_updated_at
BEFORE UPDATE ON billing.account_subscription
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_subscription_period_updated_at
BEFORE UPDATE ON billing.subscription_period
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_wallet_account_updated_at
BEFORE UPDATE ON billing.wallet_account
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_billing_payment_method_updated_at
BEFORE UPDATE ON billing.payment_method
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_payment_order_updated_at
BEFORE UPDATE ON billing.payment_order
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_refund_updated_at
BEFORE UPDATE ON billing.refund
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_billing_invoice_updated_at
BEFORE UPDATE ON billing.invoice
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_billing_invoice_item_updated_at
BEFORE UPDATE ON billing.invoice_item
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- C. Refund cumulative cap validation trigger
CREATE OR REPLACE FUNCTION billing.fn_assert_refund_cap()
RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE
    v_captured_amount numeric(14,2);
    v_total_refunded numeric(14,2);
    v_failed_status_id bigint;
BEGIN
    SELECT id INTO v_failed_status_id 
    FROM billing.refund_status 
    WHERE code = 'failed';

    SELECT amount INTO v_captured_amount
    FROM billing.payment_transaction
    WHERE id = NEW.payment_transaction_id
    FOR UPDATE;

    SELECT COALESCE(SUM(amount), 0) INTO v_total_refunded
    FROM billing.refund
    WHERE payment_transaction_id = NEW.payment_transaction_id
      AND refund_status_id <> v_failed_status_id
      AND id <> COALESCE(NEW.id, -1);

    IF (v_total_refunded + NEW.amount) > v_captured_amount THEN
        RAISE EXCEPTION 'Cumulative refund amount (%) exceeds captured payment transaction amount (%)',
            (v_total_refunded + NEW.amount), v_captured_amount;
    END IF;

    RETURN NEW;
END $$;

CREATE TRIGGER trg_refund_cap
BEFORE INSERT OR UPDATE ON billing.refund
FOR EACH ROW EXECUTE FUNCTION billing.fn_assert_refund_cap();

-- D. Wallet balance cache sync trigger
CREATE OR REPLACE FUNCTION billing.fn_sync_wallet_account_cache()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
    UPDATE billing.wallet_account
    SET cached_credit_balance = NEW.balance_after,
        updated_at = CURRENT_TIMESTAMP
    WHERE id = NEW.wallet_account_id;
    RETURN NEW;
END $$;

CREATE TRIGGER trg_wallet_balance_cache_sync
AFTER INSERT ON billing.wallet_ledger
FOR EACH ROW EXECUTE FUNCTION billing.fn_sync_wallet_account_cache();

-- E. Payment Order Purpose Consistency Guard
CREATE OR REPLACE FUNCTION billing.fn_payment_order_purpose_guard()
RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE
    v_purpose_code varchar(50);
BEGIN
    SELECT code INTO v_purpose_code 
    FROM billing.order_purpose 
    WHERE id = NEW.order_purpose_id;

    IF v_purpose_code = 'subscription' THEN
        IF NEW.subscription_period_id IS NULL OR NEW.wallet_account_id IS NOT NULL OR NEW.credits_to_grant IS NOT NULL THEN
            RAISE EXCEPTION 'Subscription payment orders must specify subscription_period_id and omit wallet target fields';
        END IF;
    ELSIF v_purpose_code = 'wallet_recharge' THEN
        IF NEW.wallet_account_id IS NULL OR NEW.credits_to_grant IS NULL OR NEW.subscription_period_id IS NOT NULL THEN
            RAISE EXCEPTION 'Wallet recharge payment orders must specify wallet_account_id and credits_to_grant and omit subscription_period_id';
        END IF;
    END IF;

    RETURN NEW;
END $$;

CREATE TRIGGER trg_payment_order_purpose_guard
BEFORE INSERT OR UPDATE ON billing.payment_order
FOR EACH ROW EXECUTE FUNCTION billing.fn_payment_order_purpose_guard();

-- F. Profile Download History Single-Funding-Source Guard
CREATE OR REPLACE FUNCTION billing.fn_profile_download_history_guard()
RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE
    v_outcome_code varchar(50);
BEGIN
    SELECT code INTO v_outcome_code 
    FROM billing.download_outcome 
    WHERE id = NEW.download_outcome_id;

    IF v_outcome_code = 'succeeded' THEN
        IF num_nonnulls(NEW.wallet_ledger_id, NEW.entitlement_usage_id) <> 1 THEN
            RAISE EXCEPTION 'Successful profile download must have exactly one funding source (wallet_ledger_id or entitlement_usage_id)';
        END IF;
    ELSE
        IF NEW.wallet_ledger_id IS NOT NULL OR NEW.entitlement_usage_id IS NOT NULL OR NEW.credits_charged <> 0 THEN
            RAISE EXCEPTION 'Non-succeeded profile download cannot charge credits or link to funding sources';
        END IF;
    END IF;

    RETURN NEW;
END $$;

CREATE TRIGGER trg_profile_download_history_guard
BEFORE INSERT OR UPDATE ON billing.profile_download_history
FOR EACH ROW EXECUTE FUNCTION billing.fn_profile_download_history_guard();

-- G. Enforce Seat Allocation Limit Against Subscription Plan Entitlement
CREATE OR REPLACE FUNCTION licence.fn_enforce_seat_cap()
RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE
    v_max_seats integer;
    v_active_seats integer;
BEGIN
    IF NEW.is_active = true THEN
        -- Find maximum seats allowed for this licence from active plan entitlement
        SELECT pe.quota INTO v_max_seats
        FROM billing.account_subscription s
        JOIN billing.subscription_status st ON st.id = s.subscription_status_id
        JOIN billing.plan_entitlement pe ON pe.subscription_plan_id = s.subscription_plan_id
        JOIN billing.feature f ON f.id = pe.feature_id
        WHERE s.licence_id = NEW.licence_id
          AND st.code = 'active'
          AND f.code = 'recruiter_seats'
        ORDER BY s.id DESC
        LIMIT 1;

        -- If a seat quota is configured, verify active seats count
        IF v_max_seats IS NOT NULL THEN
            SELECT COUNT(*) INTO v_active_seats
            FROM licence.seat_assignment
            WHERE licence_id = NEW.licence_id
              AND is_active = true
              AND id <> COALESCE(NEW.id, -1);

            IF (v_active_seats + 1) > v_max_seats THEN
                RAISE EXCEPTION 'Seat allocation limit exceeded for licence %: maximum allowed is %, current active is %',
                    NEW.licence_id, v_max_seats, v_active_seats;
            END IF;
        END IF;
    END IF;

    RETURN NEW;
END $$;

CREATE TRIGGER trg_enforce_seat_cap
BEFORE INSERT OR UPDATE OF is_active ON licence.seat_assignment
FOR EACH ROW EXECUTE FUNCTION licence.fn_enforce_seat_cap();

-- H. Seat Assignment Audit Logger Trigger
CREATE OR REPLACE FUNCTION licence.fn_seat_assignment_logger()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        INSERT INTO licence.seat_allocation_history (
            licence_id, seat_assignment_id, user_account_id, action_type,
            actor_user_id, reason, created_at
        ) VALUES (
            NEW.licence_id, NEW.id, NEW.user_account_id, 'assigned',
            NEW.created_by, 'Seat allocated', CURRENT_TIMESTAMP
        );
    ELSIF TG_OP = 'UPDATE' THEN
        IF OLD.is_active = true AND NEW.is_active = false THEN
            INSERT INTO licence.seat_allocation_history (
                licence_id, seat_assignment_id, user_account_id, action_type,
                actor_user_id, reason, created_at
            ) VALUES (
                NEW.licence_id, NEW.id, NEW.user_account_id, 'revoked',
                COALESCE(NEW.updated_by, NEW.created_by), 'Seat revoked', CURRENT_TIMESTAMP
            );
        ELSIF OLD.is_active = false AND NEW.is_active = true THEN
            INSERT INTO licence.seat_allocation_history (
                licence_id, seat_assignment_id, user_account_id, action_type,
                actor_user_id, reason, created_at
            ) VALUES (
                NEW.licence_id, NEW.id, NEW.user_account_id, 'assigned',
                COALESCE(NEW.updated_by, NEW.created_by), 'Seat reactivated', CURRENT_TIMESTAMP
            );
        END IF;
    END IF;
    RETURN NEW;
END $$;

CREATE TRIGGER trg_seat_assignment_audit_logger
AFTER INSERT OR UPDATE OF is_active ON licence.seat_assignment
FOR EACH ROW EXECUTE FUNCTION licence.fn_seat_assignment_logger();

-- ============================================================================
-- 9. GIN TRIGRAM AUTOCOMPLETE INDEXES (pg_trgm)
-- ============================================================================

CREATE INDEX idx_subscription_plan_code_trgm ON billing.subscription_plan USING gin (code gin_trgm_ops);
CREATE INDEX idx_invoice_number_trgm ON billing.invoice USING gin (invoice_number gin_trgm_ops);

-- ============================================================================
-- 10. ROW-LEVEL SECURITY & ACTIVE CONVENIENCE VIEWS (Rule Group 9)
-- ============================================================================

ALTER TABLE licence.licence ENABLE ROW LEVEL SECURITY;
ALTER TABLE licence.seat_assignment ENABLE ROW LEVEL SECURITY;
ALTER TABLE licence.registered_device ENABLE ROW LEVEL SECURITY;
ALTER TABLE licence.seat_allocation_history ENABLE ROW LEVEL SECURITY;

ALTER TABLE billing.account_subscription ENABLE ROW LEVEL SECURITY;
ALTER TABLE billing.wallet_account ENABLE ROW LEVEL SECURITY;
ALTER TABLE billing.wallet_ledger ENABLE ROW LEVEL SECURITY;
ALTER TABLE billing.payment_order ENABLE ROW LEVEL SECURITY;
ALTER TABLE billing.invoice ENABLE ROW LEVEL SECURITY;

CREATE OR REPLACE VIEW licence.v_active_seat_roster AS
SELECT 
    sa.id AS seat_assignment_id,
    sa.licence_id,
    l.account_id,
    sa.user_account_id,
    u.email AS user_email,
    sa.assigned_at,
    COUNT(rd.id) FILTER (WHERE rd.revoked_at IS NULL) AS active_device_count
FROM licence.seat_assignment sa
JOIN licence.licence l ON l.id = sa.licence_id
JOIN administration.user_account u ON u.id = sa.user_account_id
LEFT JOIN licence.registered_device rd ON rd.seat_assignment_id = sa.id
WHERE sa.is_active = true
GROUP BY sa.id, sa.licence_id, l.account_id, sa.user_account_id, u.email, sa.assigned_at;

CREATE OR REPLACE VIEW billing.v_active_subscription_contract AS
SELECT 
    s.id AS subscription_id,
    s.account_id,
    a.organisation_id,
    s.licence_id,
    p.code AS plan_code,
    p.name_key AS plan_name_key,
    st.code AS status_code,
    sp.valid_range AS current_period_range,
    pp.amount AS current_period_price,
    pp.currency_code
FROM billing.account_subscription s
JOIN organisation.account a ON a.id = s.account_id
JOIN billing.subscription_plan p ON p.id = s.subscription_plan_id
JOIN billing.subscription_status st ON st.id = s.subscription_status_id
LEFT JOIN billing.subscription_period sp ON sp.account_subscription_id = s.id 
    AND sp.cancelled_at IS NULL 
    AND sp.valid_range @> CURRENT_TIMESTAMP
LEFT JOIN billing.plan_price pp ON pp.id = sp.plan_price_id
WHERE st.code IN ('pending', 'active', 'past_due');

CREATE OR REPLACE VIEW billing.v_account_wallet_summary AS
SELECT 
    w.id AS wallet_account_id,
    w.account_id,
    a.organisation_id,
    w.cached_credit_balance,
    w.last_reconciled_at
FROM billing.wallet_account w
JOIN organisation.account a ON a.id = w.account_id;

CREATE OR REPLACE VIEW billing.v_monthly_recurring_revenue_kpi AS
SELECT 
    pp.currency_code,
    COUNT(DISTINCT s.account_id) AS active_subscribing_accounts,
    COUNT(s.id) AS total_active_subscriptions,
    SUM(
        CASE 
            WHEN bi.code = 'monthly' THEN pp.amount
            WHEN bi.code = 'quarterly' THEN ROUND(pp.amount / 3.0, 2)
            WHEN bi.code = 'annual' THEN ROUND(pp.amount / 12.0, 2)
            ELSE 0
        END
    ) AS estimated_mrr
FROM billing.account_subscription s
JOIN billing.subscription_plan p ON p.id = s.subscription_plan_id
JOIN billing.billing_interval bi ON bi.id = p.billing_interval_id
JOIN billing.subscription_status st ON st.id = s.subscription_status_id
JOIN billing.subscription_period sp ON sp.account_subscription_id = s.id 
    AND sp.cancelled_at IS NULL 
    AND sp.valid_range @> CURRENT_TIMESTAMP
JOIN billing.plan_price pp ON pp.id = sp.plan_price_id
WHERE st.code = 'active'
GROUP BY pp.currency_code;

COMMIT;
