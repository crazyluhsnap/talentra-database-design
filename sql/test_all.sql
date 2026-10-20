-- ============================================================================
-- Talentra Enterprise: Master Regression Test Runner
-- Runs all test suites with transaction-isolated rollback guarantees.
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

\echo '>>> ALL MULTI-MODULE TEST SUITES PASSED WITH ZERO REGRESSIONS!'
