# Talentra Database Design

PostgreSQL database architecture, schema definitions, seed data, and formal specification for the **Talentra Job Search & Demand Management Platform** hackathon.

---

## Project Overview

Talentra is a high-performance talent platform designed to bridge permanent hiring, lateral recruitment, campus placements, and freelance/gig workforce workflows. 

This repository contains the complete physical and logical database design for **Phase 1 (Foundation)**, covering:
1. **Master Data Module:** Global reference vocabularies, geographies, localized UI strings, and domain lookup tables.
2. **Candidate Profile Module:** Candidate identities, contacts, academic records, work experience, skill matrices, multilingual profiles, portfolio projects, certifications, preferences, and forensic view logs.
3. **Jobs & Applications (Recruitment) Module:** Job requisitions, screening questionnaires with option trees, applications, multi-panel interview feedback, offers, and immutable pipeline status histories.

---

## Technology Stack

* **Database Engine:** PostgreSQL 14+
* **Primary Key Strategy:** 64-bit integer surrogate keys (`id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY`)
* **Integrity Enforcement:** Native PostgreSQL check constraints, foreign keys with explicit cascade/restrict policies, and automated PL/pgSQL triggers (`set_updated_at()`, `enforce_append_only()`)
* **Search & Indexing:** B-Tree, Partial Indexes, GIN Trigram Autocomplete (`pg_trgm`), and GIN Full-Text Search (`tsvector`)
* **Character Encoding:** UTF-8 throughout

---

## Repository Structure

```text
talentra-database-design/
├── docs/                                   # Architectural documentation & registers
│   ├── competitive-coverage-benchmark.md   # Benchmark vs. LinkedIn, Naukri & Superset
│   ├── data-dictionary-phase-1.md          # Nullability justifications & data classifications
│   ├── er-diagram-phase-1.mermaid          # Baseline Mermaid ER Diagram (Step 21)
│   ├── phase-1-architecture-specification.md # Physical schema & scaling architecture
│   ├── phase-1-foundation.md               # B1–B23 milestones & Phase 2 readiness matrix
│   └── phase-2-administration-specification.md # B24, B27, B30, B33 Administration & Identity Spec
├── sql/                                    # Production PostgreSQL scripts
│   ├── schema.sql                          # Complete Phase 1 DDL (54 Tables, 59 Indexes, 27 Triggers)
│   ├── seed.sql                            # Phase 1 seed data for testing & demonstrations
│   ├── integrity_regression_test.sql       # 16 Phase 1 negative & invariant test scenarios
│   ├── phase2_administration.sql           # Phase 2 Administration DDL (11 Tables, 20 Indexes, 4 Triggers)
│   ├── seed_administration.sql             # Phase 2 roles, permissions, reconciliation & bridge FK
│   └── administration_regression_test.sql  # 24 Phase 2 ADM-001..24 regression test scenarios
├── inspect_schema.py                       # Python validation script inspecting full 4-schema structure
└── README.md                               # Project documentation & execution guide
```

---

## Schema Architecture Summary

| Schema Domain | Tables | Key Focus Areas |
| :--- | :---: | :--- |
| `master_data` | **23** | Countries, states, cities, locations, currencies, languages, UI translations, and relational lookups avoiding hardcoded string enums |
| `profile` | **18** | Candidate profile, contact (E.164 + lowercase checks, partial unique indexes), education, experience, skill/language bridges, projects, resumes, certifications, preferences, awards, view history |
| `recruitment` | **13** | Job requirements, required skills, versioned questionnaires, typed questions & choices, applications, candidate answers, interviews, feedback, offers, automated status transition history |
| `administration` | **11** | User accounts, Argon2id credentials, RBAC roles/permissions, temporal user_roles, hashed sessions, append-only consent & audit ledgers, directional user/organisation blocking |
| **Total** | **65** | **79 Indexes, 31 Automated Triggers, 40 Combined Regression Tests, 100% Rule Groups 1–10 Compliant** |

---

## Development & Milestone Status

### Phase 1 Foundation (B1–B23)
- [x] **B1–B3:** Engine & module scope agreed (`master_data`, `profile`, `recruitment`)
- [x] **B4–B7:** Entity identification & normalization
- [x] **B8–B11:** Relationship & cardinality modeling
- [x] **B12–B15:** Standard column contracts, data classifications, and nullability justifications
- [x] **B16–B19:** Logical ER models & physical specifications
- [x] **B20–B23:** Constraints, triggers, indexes, and final Phase 1 sign-off

### Phase 2 Administration & Identity (B24, B27, B30, B33)
- [x] **B24:** Administration entity map & scope boundaries defined (11 tables)
- [x] **B27:** Relationship model, cardinalities, and Phase 1 bridge foreign key attachment
- [x] **B30:** Column dictionary, Argon2id/bytea security contracts, nullability justifications, and data classifications
- [x] **B33:** Keys, constraints, partial unique indexes, append-only audit/consent triggers, and ADM-001..24 test suite

---

## Verification & Inspection

To inspect and validate the DDL structure:
```bash
python inspect_schema.py
```

To load the schema and seed data into a local PostgreSQL database:
```bash
# 1. Create database
psql -U postgres -c "CREATE DATABASE talentra;"

# 2. Run DDL schema
psql -U postgres -d talentra -f sql/schema.sql

# 3. Load seed records
psql -U postgres -d talentra -f sql/seed.sql
```

---

## Phase 2 Integration Readiness

Phase 1 provides clean, decoupled foreign key integration points ready for future phases:
* **Authentication (`auth` module):** Pre-wired via `candidate_profile.user_id` and `recruitment.job_requirement.created_by_user_id`.
* **Organisations & Employers (`organisation` module):** Pre-wired via `job_requirement.organisation_id`.
* **Wallets & Credits (`billing` module):** Pre-wired via `profile.profile_view_history.credit_deducted` and `profile.candidate_referral.reward_amount`.
