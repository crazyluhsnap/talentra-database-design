-- ============================================================================
-- Talentra Enterprise: Master Regression Test Runner
-- Runs all test suites with transaction-isolated rollback guarantees.
-- Covers Phase 1 Foundation, Phase 2 Enterprise, and Phase 3 Sourcing & Billing.
-- ============================================================================

\set ON_ERROR_STOP on

\echo '>>> Running Phase 1 Integrity Regression Tests...'
\ir integrity_regression_test.sql

\echo '>>> Running Phase 2 Administration Regression Tests...'
\ir administration_regression_test.sql

\echo '>>> Running Phase 2 Organisation Regression Tests...'
\ir organisation_regression_test.sql

\echo '>>> Running Phase 2 Gig Marketplace Regression Tests...'
\ir gig_regression_test.sql

\echo '>>> Running Phase 3 Module A (Sourcing) Regression Tests...'
\ir sourcing_regression_test.sql

\echo '>>> Running Phase 3 Module B (Subscriptions & Wallet) Regression Tests...'
\ir billing_subscriptions_regression_test.sql

\echo '>>> Running Phase 4 Module A (Engagement & Notifications) Regression Tests...'
\ir phase4_engagement_regression_test.sql

\echo '>>> Running Phase 4 Module B (Analytics Marts) Regression Tests...'
\ir phase4_analytics_regression_test.sql

\echo '>>> Running Phase 4 Module C (Governance & Blocking) Regression Tests...'
\ir phase4_governance_regression_test.sql

\echo '>>> Running Phase 5 Security & Access Control Regression Tests (B79)...'
\ir phase5_security_regression_test.sql

\echo '>>> ALL MULTI-MODULE TEST SUITES PASSED WITH ZERO REGRESSIONS!'
