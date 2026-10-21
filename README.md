# Talentra Database Design

PostgreSQL database architecture, schema definitions, seed data, and formal specification for the **Talentra Job Search & Demand Management Platform**.

---

## Project Overview

Talentra is a high-performance talent platform designed to bridge permanent hiring, lateral recruitment, campus placements, and freelance/gig workforce workflows. 

This repository contains the complete physical and logical database design across **Phase 1 (Foundation)**, **Phase 2 (Enterprise Tenancy & Marketplace)**, and **Phase 3 (Sourcing, Subscriptions, Wallet & Payments)**:

1. **Master Data Module (`master_data`)**: Global reference vocabularies, geographies, ISO currencies/languages, service taxonomy, and domain lookup tables (24 tables).
2. **Candidate Profile Module (`profile`)**: Candidate identities, contacts (E.164), academic records, work experience, skill matrices, multilingual profiles, portfolio projects, certifications, preferences, and forensic view logs (18 tables).
3. **Jobs & Applications Module (`recruitment`)**: Job requisitions, screening questionnaires with option trees, applications, multi-panel interview feedback, offers, and immutable pipeline status histories (13 tables).
4. **Administration & Identity Module (`administration`)**: User accounts, Argon2id credentials, RBAC roles/permissions, temporal user_roles, hashed sessions, append-only consent & audit ledgers, directional user/organisation blocking (17 tables).
5. **Organisation & Tenancy Module (`organisation`)**: Multi-tenant company hierarchy, corporate accounts, recruiter team seats, branch locations, KYC/compliance verification, and monthly partitioned enterprise audit logs (24 tables).
6. **Gig Marketplace Subsystem (`gig`)**: Freelance service catalog, availability calendars, gig job requests, bid proposals, milestone contracts, deliverable submissions, dispute mediation, and two-way review matrices (27 tables).
7. **Sourcing & Consultant Requests (`sourcing`)**: Consultant-led sourcing requests on open jobs, employer decision histories, bulk outreach campaign batches, recipient tracking, and shortlisted candidate provenance linkage (13 tables).
8. **Licences Anchor (`licence`)**: Cross-module enterprise license contracts (1 table).
9. **Subscriptions, Wallet, Payments & Download History (`billing`)**: Commercial plans, effective-dated prices with range exclusion constraints (`EXCLUDE USING gist`), non-overlapping subscription contract periods per licence, quota entitlement usage, credit wallets with cached balance synchronization, idempotent payment orders/transactions/inboxes, cumulative refund caps, and single-funding-source profile download histories (31 tables).

---

## Technology Stack

* **Database Engine:** PostgreSQL 16+ (leveraging exclusion constraints `EXCLUDE USING gist`, Row-Level Security, and temporal range types `daterange`/`tstzrange`)
* **Primary Key Strategy:** 64-bit integer surrogate keys (`id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY`)
* **Integrity Enforcement:** Native PostgreSQL check constraints, foreign keys with explicit cascade/restrict policies, and automated PL/pgSQL triggers (`set_updated_at()`, `enforce_append_only()`, `fn_assert_refund_cap()`, `fn_sync_wallet_account_cache()`)
* **Search & Indexing:** B-Tree, Partial Indexes, GIN Trigram Autocomplete (`pg_trgm`), and GIN Full-Text Search (`tsvector`)
* **Character Encoding:** UTF-8 throughout

---

## Repository Structure

```text
talentra-database-design/
├── docs/                                           # Architectural documentation & registers
│   ├── phase-1-architecture-specification.md       # Phase 1 Foundation master spec
│   ├── phase-2-architecture-specification.md       # Phase 2 Administration, Organisation & Gig spec
│   ├── phase-3-full-architecture-specification.md  # Phase 3 Sourcing, Subscriptions & Wallet master spec
│   ├── master-architecture-plan-and-phase3-roadmap.md # Master architecture flow & roadmap
│   ├── ddd-lifecycle-verification-and-traceability.md # DDD Gates G1–G8 audit & traceability matrix
│   ├── qfe-five-schemas-architecture.md            # QFE 5 nonlinear schema reference
│   ├── competitive-coverage-benchmark.md           # Benchmark vs. LinkedIn, Naukri & Superset
│   └── data-dictionary-phase-1.md                  # Nullability justifications & data classifications
├── sql/                                            # Production PostgreSQL scripts
│   ├── schema.sql                                  # Phase 1 Foundation DDL (54 Tables)
│   ├── phase2_administration.sql                   # Phase 2 Administration DDL (17 Tables)
│   ├── phase2_organisation.sql                     # Phase 2 Organisation DDL (24 Tables)
│   ├── phase2_gig_marketplace.sql                  # Phase 2 Gig Marketplace DDL (27 Tables)
│   ├── phase3_sourcing.sql                         # Phase 3 Module A Sourcing DDL (13 Tables)
│   ├── phase3_billing_subscriptions.sql            # Phase 3 Module B Subscriptions & Wallet DDL (32 Tables)
│   ├── seed.sql                                    # Phase 1 Master & Candidate seed data
│   ├── seed_administration.sql                     # Phase 2 Administration & Role seed data
│   ├── seed_organisation.sql                       # Phase 2 Organisation & Account seed data
│   ├── seed_gig_marketplace.sql                    # Phase 2 Gig Marketplace seed data
│   ├── seed_phase3_sourcing.sql                    # Phase 3 Sourcing taxonomy & fixtures
│   ├── seed_phase3_billing.sql                     # Phase 3 Plans, Prices, Features, Wallet & Subscriptions
│   ├── integrity_regression_test.sql               # Phase 1 regression test suite (16 tests)
│   ├── administration_regression_test.sql          # Phase 2 Administration test suite (30 tests)
│   ├── organisation_regression_test.sql            # Phase 2 Organisation test suite (21 tests)
│   ├── gig_regression_test.sql                     # Phase 2 Gig Marketplace test suite (9 assertions)
│   ├── sourcing_regression_test.sql                # Phase 3 Sourcing regression test suite (10 assertions)
│   ├── billing_subscriptions_regression_test.sql   # Phase 3 Subscriptions & Wallet regression suite (10 assertions)
│   ├── setup_all.sql                               # Master 1-Click Provisioning Runner
│   └── test_all.sql                                # Master 1-Click Regression Test Runner
├── inspect_schema.py                               # Schema inspection & table counter
├── run_all_tests.py                                # Master 44-suite automated verification engine
└── README.md                                       # Project documentation & execution guide
```

---

## Schema Architecture Summary

| Schema Domain | Tables | Indexes | Triggers | Key Focus Areas |
| :--- | :---: | :---: | :---: | :--- |
| `master_data` | **24** | 21 | 2 | Countries, states, cities, locations, currencies, languages, industries, service categories, and relational lookups |
| `profile` | **18** | 23 | 12 | Candidate profiles, contacts (E.164), education, experience, skill/language bridges, projects, resumes, certifications |
| `recruitment` | **13** | 15 | 8 | Job requisitions, versioned questionnaires, typed questions & choices, applications, interviews, feedback, offers |
| `administration` | **17** | 22 | 8 | User identity, Argon2id credentials, RBAC roles/permissions, temporal user_roles, sessions, consent, blocking |
| `organisation` | **24** | 22 | 26 | Multi-tenant company hierarchy, corporate accounts, recruiter team seats, branches, KYC, monthly partitioned audit trails |
| `gig` | **27** | 19 | 16 | Freelance service catalog, availability calendars, gig requests, proposals, milestone contracts, deliverables, reviews |
| `sourcing` | **13** | 20 | 12 | Consultant sourcing requests, decisions, outreach batches, shortlist provenance |
| `licence` | **1** | 1 | 2 | Cross-module enterprise license contracts |
| `billing` | **31** | 44 | 26 | Commercial plans, prices, exclusion periods, payments, refunds, invoices, credit wallet |
| **Total** | **168** | **187** | **112** | **Full Phase 1, Phase 2, & Phase 3 Scope (100% PRD & DDD Compliant)** |

---

## Verification & Execution Guide

### 1. Automated Architecture Validation (Zero-Database Required)
```bash
python run_all_tests.py
```
*(Runs 44 verification suites and validates zero duplication across 168 tables and 143 indexes).*

### 2. Inspect Schema Structure
```bash
python inspect_schema.py
```

### 3. Deploy to PostgreSQL in 1 Single Command
```bash
# Create database
psql -U postgres -c "CREATE DATABASE talentra;"

# Deploy all 8 schemas and seed fixtures in strict dependency order
psql -U postgres -d talentra -f sql/setup_all.sql
```

### 4. Run Transaction-Isolated Regression Tests in PostgreSQL
```bash
psql -U postgres -d talentra -f sql/test_all.sql
```
*(Executes all multi-module test suites with rollback guarantees).*
