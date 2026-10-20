-- ============================================================================
-- Talentra Enterprise: Master Schema & Seed Pipeline (Phase 1 & Phase 2)
-- Executes in strict dependency order:
-- 1. Phase 1 Foundation (master_data, profile, recruitment)
-- 2. Phase 2 Administration (identity, rbac, privacy, blocks)
-- 3. Phase 2 Organisation (tenancy, accounts, locations, verifications, audit)
-- 4. Phase 2 Gig Marketplace (services, availability, requests, assignments)
-- 5. Seed Data in Dependency Order
-- ============================================================================

\set ON_ERROR_STOP on

\echo '>>> Deploying Phase 1 Foundation Schemas...'
\ir schema.sql

\echo '>>> Deploying Phase 2 Administration Module...'
\ir phase2_administration.sql

\echo '>>> Deploying Phase 2 Organisation and Account Module...'
\ir phase2_organisation.sql

\echo '>>> Deploying Phase 2 Gig Marketplace Subsystem...'
\ir phase2_gig_marketplace.sql

\echo '>>> Seeding Phase 1 Master Data & Core Fixtures...'
\ir seed.sql

\echo '>>> Seeding Phase 2 Administration & Role Matrices...'
\ir seed_administration.sql

\echo '>>> Seeding Phase 2 Organisation & Corporate Tenancy...'
\ir seed_organisation.sql

\echo '>>> Seeding Phase 2 Gig Marketplace Taxonomy & Fixtures...'
\ir seed_gig_marketplace.sql

\echo '>>> ALL SCHEMAS AND SEEDS DEPLOYED SUCCESSFULLY!'
