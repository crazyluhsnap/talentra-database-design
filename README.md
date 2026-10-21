# Talentra Database Design

PostgreSQL enterprise database architecture, schema definitions, seed data, and formal specifications for the **Talentra Job Search & Demand Management Platform**.

---

## Project Overview

Talentra is a high-performance talent platform designed to bridge permanent hiring, lateral recruitment, campus placements, freelance/gig marketplace workflows, social community engagement, and enterprise analytical intelligence.

This repository contains the complete physical and logical database design across **Phase 1 (Foundation)**, **Phase 2 (Enterprise Tenancy & Marketplace)**, **Phase 3 (Sourcing, Subscriptions & Wallet)**, and **Phase 4 (Engagement, Community, Analytics & Governance)**:

1. **Master Data Module (`master_data`)**: Global reference vocabularies, geographies, ISO currencies/languages, service taxonomy, job categories, and domain lookup tables (25 tables).
2. **Candidate Profile Module (`profile`)**: Candidate identities, contacts (E.164), academic records, work experience, skill matrices, multilingual profiles, portfolio projects, certifications, preferences, and forensic view logs (18 tables).
3. **Jobs & Applications Module (`recruitment`)**: Job requisitions, screening questionnaires with option trees, applications, multi-panel interview feedback, offers, and immutable pipeline status histories (13 tables).
4. **Administration, Identity & Governance Module (`administration`)**: User accounts, Argon2id credentials, RBAC roles/permissions, temporal user_roles, hashed sessions, append-only consent & audit ledgers, directional user/organisation blocking, security definer visibility functions (`candidate_visible_to`), concurrent session locking (`start_user_session`), DPDP consent policies, password reset tokens, error logging, and data subject requests (41 tables).
5. **Organisation & Tenancy Module (`organisation`)**: Multi-tenant company hierarchy, corporate accounts, recruiter team seats, branch locations, KYC/compliance verification, and monthly partitioned enterprise audit logs (24 tables).
6. **Gig Marketplace Subsystem (`gig`)**: Freelance service catalog, availability calendars, gig job requests, bid proposals, milestone contracts, deliverable submissions, dispute mediation, and two-way review matrices (27 tables).
7. **Sourcing & Consultant Requests (`sourcing`)**: Consultant-led sourcing requests on open jobs, employer decision histories, bulk outreach campaign batches, recipient tracking, and shortlisted candidate provenance linkage (13 tables).
8. **Licensing & Seat Management Subsystem (`licence`)**: Cross-module enterprise license contracts, named recruiter seat quota enforcement, hardware device fingerprint tokens, and immutable seat allocation audit logs (4 tables).
9. **Subscriptions, Wallet, Payments & Download History (`billing`)**: Commercial plans, effective-dated prices with range exclusion constraints (`EXCLUDE USING gist`), non-overlapping subscription contract periods per licence, quota entitlement usage, credit wallets with cached balance synchronization, idempotent payment orders/transactions/inboxes, cumulative refund caps, and single-funding-source profile download histories (31 tables).
10. **Engagement, Preferences, Notifications & Community (`engagement`)**: Notification templates, translations, monthly range-partitioned deliveries (`notification_delivery`) and attempts, provider inbox idempotency, suppression lists, quiet hours, structured search criteria, monster-style saved resume searches, job alert runs, social community topics/posts/reactions/comments, typed reports and moderation actions, support tickets with SLAs, and wallet-linked referral rewards (57 tables).
11. **Analytics Star Schema & Reporting Marts (`analytics`)**: Kimball-style data mart comprising 18 dimensions (including SCD2 dimensions with GiST exclusion constraints on candidate, gig worker, and organisation), 16 monthly-partitioned fact tables (covering gig revenue, wallet transactions, profile downloads, and pipeline snapshots), 9 aggregate marts with full grain uniqueness, 5 ETL control tables, and small-cell privacy masking views (48 tables).

---

## Technology Stack

* **Database Engine:** PostgreSQL 16+ (leveraging exclusion constraints `EXCLUDE USING gist`, Row-Level Security, partition pruning, and temporal range types `daterange`/`tstzrange`)
* **Primary Key Strategy:** 64-bit integer surrogate keys (`id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY`) with smart integer keys for dimensions (`dim_date.id = YYYYMMDD`)
* **Integrity Enforcement:** Native PostgreSQL check constraints, foreign keys with explicit cascade/restrict policies, and automated PL/pgSQL triggers (`set_updated_at()`, `enforce_append_only()`, `fn_can_deliver()`, `fn_support_ticket_status_logger()`)
* **Concurrency & Security:** `FOR UPDATE` user serialization, security definer functions (`candidate_visible_to`), Argon2id password hashing, SHA-256 tokens, AES-256-GCM encrypted tokens
* **Search & Indexing:** B-Tree, Partial Indexes (`WHERE is_open`), GIN Trigram Autocomplete (`pg_trgm`), and GIN Full-Text Search (`tsvector`)
* **Character Encoding:** UTF-8 throughout

---

## Repository Structure

```text
talentra-database-design/
├── docs/                                           # Architectural documentation & registers
│   ├── phase-1-architecture-specification.md       # Phase 1 Foundation master spec
│   ├── phase-2-architecture-specification.md       # Phase 2 Administration, Organisation & Gig spec
│   ├── phase-3-full-architecture-specification.md  # Phase 3 Sourcing, Subscriptions & Wallet master spec
│   ├── phase-4-full-architecture-specification.md  # Phase 4 Engagement, Analytics & Governance spec & 52-Gap Dossier
│   ├── requirement-analysis-docket.md              # Formal requirement analysis docket (Step 01)
│   ├── master-architecture-plan-and-phase3-roadmap.md # Master architecture flow & roadmap
│   ├── ddd-lifecycle-verification-and-traceability.md # DDD Gates G1–G8 audit & traceability matrix
│   ├── qfe-five-schemas-architecture.md            # QFE 5 nonlinear schema reference
│   ├── competitive-coverage-benchmark.md           # Benchmark vs. LinkedIn, Naukri & Superset
│   └── data-dictionary-phase-1.md                  # Nullability justifications & data classifications
├── sql/                                            # Production PostgreSQL scripts
│   ├── schema.sql                                  # Phase 1 Foundation DDL (55 Tables)
│   ├── phase2_administration.sql                   # Phase 2 Administration DDL (17 Tables)
│   ├── phase2_organisation.sql                     # Phase 2 Organisation DDL (24 Tables)
│   ├── phase2_gig_marketplace.sql                  # Phase 2 Gig Marketplace DDL (27 Tables)
│   ├── phase3_sourcing.sql                         # Phase 3 Module A Sourcing DDL (13 Tables)
│   ├── phase3_billing_subscriptions.sql            # Phase 3 Module B Subscriptions & Licensing DDL (35 Tables)
│   ├── phase4_engagement_community.sql             # Phase 4 Module A Engagement & Community DDL (57 Tables)
│   ├── phase4_analytics_marts.sql                  # Phase 4 Module B Analytics Layer & Marts DDL (48 Tables)
│   ├── phase4_governance_shared.sql                # Phase 4 Module C Shared Governance & Privacy DDL (24 Tables)
│   ├── seed.sql                                    # Phase 1 Master & Candidate seed data
│   ├── seed_administration.sql                     # Phase 2 Administration & Role seed data
│   ├── seed_organisation.sql                       # Phase 2 Organisation & Account seed data
│   ├── seed_gig_marketplace.sql                    # Phase 2 Gig Marketplace seed data
│   ├── seed_phase3_sourcing.sql                    # Phase 3 Sourcing taxonomy & fixtures
│   ├── seed_phase3_billing.sql                     # Phase 3 Plans, Prices, Features, Wallet & Subscriptions
│   ├── seed_phase4_engagement.sql                  # Phase 4 Templates, Search Criteria, Topics, FAQs
│   ├── seed_phase4_analytics.sql                   # Phase 4 dim_date Calendar & 8 Job Categories
│   ├── seed_phase4_governance.sql                  # Phase 4 DPDP Policies, Retention Rules & Lookups
│   ├── integrity_regression_test.sql               # Phase 1 regression test suite (16 tests)
│   ├── administration_regression_test.sql          # Phase 2 Administration test suite (30 tests)
│   ├── organisation_regression_test.sql            # Phase 2 Organisation test suite (21 tests)
│   ├── gig_regression_test.sql                     # Phase 2 Gig Marketplace test suite (9 assertions)
│   ├── sourcing_regression_test.sql                # Phase 3 Sourcing regression test suite (13 assertions)
│   ├── billing_subscriptions_regression_test.sql   # Phase 3 Subscriptions & Licensing regression suite (16 assertions)
│   ├── phase4_engagement_regression_test.sql       # Phase 4 Engagement regression test suite (12 assertions)
│   ├── phase4_analytics_regression_test.sql        # Phase 4 Analytics Marts regression test suite (12 assertions)
│   ├── phase4_governance_regression_test.sql       # Phase 4 Governance & Privacy regression suite (12 assertions)
│   ├── seed_phase5_synthetic.sql                   # Phase 5 Synthetic multi-module fixture (Milestone 19: B60-B64)
│   ├── phase5_queries.sql                          # Phase 5 Fixed query set & execution plans (Milestone 20: B65)
│   ├── phase5_module_queries.sql                   # Phase 5 Module queries for Member A, B, C (Milestone 20: B67-B69)
│   ├── phase5_security_regression_test.sql         # Phase 5 Security & Access regression suite (Milestone 22: B79)
│   ├── setup_all.sql                               # Master 1-Click Provisioning Runner
│   └── test_all.sql                                # Master 1-Click Regression Test Runner
├── docs/                                           # Architecture, Performance & Sign-off Dossiers
│   ├── phase-5-seed-validation-report.md           # Milestone 20: B66 Section 5 seed validation report
│   ├── phase-5-performance-baseline-and-extrapolation.md # Milestone 21: B70-B74 p50/p95/p99 & 100M extrapolation
│   ├── phase-5-security-design-note.md             # Milestone 22: B75-B78, B81 STRIDE threat model & PII handling
│   ├── phase-5-backup-restore-and-rto-log.md       # Milestone 23: B80 Backup/Restore log (7m 18s RTO vs 30m SLA)
│   └── phase-5-gate-2-sign-off.md                  # Milestone 23: B82 Full 82-backlog Gate 2 sign-off
├── talentra_seed_generator.py                      # Streaming synthetic seed generator (1M laptop / 10M full)
├── inspect_schema.py                               # Schema inspection & table counter (301 tables)
├── run_all_tests.py                                # Master 95-suite automated verification engine
└── README.md                                       # Project documentation & execution guide
```

---

## Schema Architecture Summary

| Schema Domain | Tables | Indexes | Triggers | Key Focus Areas |
| :--- | :---: | :---: | :---: | :--- |
| `master_data` | **25** | 21 | 2 | Countries, states, cities, locations, currencies, languages, industries, job categories, service taxonomy, lookups |
| `profile` | **18** | 23 | 12 | Candidate profiles, contacts (E.164), education, experience, skill/language bridges, projects, resumes, certifications |
| `recruitment` | **13** | 15 | 8 | Job requisitions, versioned questionnaires, typed questions & choices, applications, interviews, feedback, offers |
| `administration` | **41** | 33 | 16 | User identity, Argon2id credentials, RBAC matrices, sessions, consent, blocking, DPDP policies, error logs, requests |
| `organisation` | **24** | 22 | 26 | Multi-tenant company hierarchy, corporate accounts, recruiter team seats, branches, KYC, monthly partitioned audit trails |
| `gig` | **27** | 19 | 16 | Freelance service catalog, availability calendars, gig requests, proposals, milestone contracts, deliverables, reviews |
| `sourcing` | **13** | 20 | 12 | Consultant sourcing requests, decisions, outreach batches, shortlist provenance |
| `licence` | **4** | 8 | 8 | Cross-module enterprise license contracts, named recruiter seat quota enforcement, device security, audit history |
| `billing` | **31** | 44 | 26 | Commercial plans, prices, exclusion periods, payments, refunds, invoices, credit wallet |
| `engagement` | **57** | 22 | 27 | Partitioned notification delivery, search criteria, alerts, community topics/posts/reactions, support SLAs, referrals |
| `analytics` | **48** | 14 | 4 | 18 dimensions (SCD2 GiST exclusions), 16 partitioned facts (gig, wallet, downloads), 9 aggregate marts, 5 control tables |
| **Total** | **301** | **221** | **157** | **Complete Phase 1 to Phase 5 Scope (100% PRD, Docket & Gate 2 Approved)** |

---

## Verification & Execution Guide

### 1. Automated Architecture & Regression Verification (Zero-Database Required)
```bash
python run_all_tests.py
```
*(Runs all 95 verification suites validating foreign keys, index targets, invariants, seeds, execution plans, security assertions, and zero duplication across all 301 tables).*

### 2. Run Synthetic Seed Generator
```bash
# Generate sample test fixtures
python talentra_seed_generator.py --mode sample --out sql/seed_phase5_synthetic.sql

# Generate full laptop-scale dataset (1M profiles, 100k jobs, 5M applications)
python talentra_seed_generator.py --mode laptop --out sql/seed_phase5_laptop.sql
```

### 3. Inspect Schema Structure
```bash
python inspect_schema.py
```

### 4. Deploy to PostgreSQL in 1 Single Command
```bash
# Create database
psql -U postgres -c "CREATE DATABASE talentra;"

# Deploy all 10 schemas and seed fixtures in strict dependency order (Phases 1-5)
psql -U postgres -d talentra -f sql/setup_all.sql
```

### 5. Run Transaction-Isolated Regression Tests in PostgreSQL
```bash
psql -U postgres -d talentra -f sql/test_all.sql
```
*(Executes all multi-module test suites including Phase 5 security controls with transaction-isolated rollback guarantees).*
