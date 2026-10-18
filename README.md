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
│   ├── phase-1-architecture-specification.md # Physical schema & scaling architecture
│   └── phase-1-foundation.md               # B1–B23 milestones & Phase 2 readiness matrix
├── sql/                                    # Production PostgreSQL scripts
│   ├── schema.sql                          # Complete DDL (Schemas, 54 Tables, 59 Indexes, 22 Triggers)
│   └── seed.sql                            # Comprehensive seed data for testing & demonstrations
├── inspect_schema.py                       # Python validation script inspecting schema structure
└── README.md                               # Project documentation & execution guide
```

---

## Schema Architecture Summary

| Schema Domain | Tables | Key Focus Areas |
| :--- | :---: | :--- |
| `master_data` | **23** | Countries, states, cities, locations, currencies, languages, UI translations, and relational lookups avoiding hardcoded string enums |
| `profile` | **18** | Candidate profile, contact (E.164 + lowercase checks), education, experience, skill/language bridges, projects, resumes, certifications, preferences, awards, view history |
| `recruitment` | **13** | Job requirements, required skills, versioned questionnaires, typed questions & choices, applications, candidate answers, interviews, feedback, offers, status histories |
| **Total** | **54** | **59 Indexes, 22 Automated Triggers, 100% Rule Groups 1–10 Compliant** |

---

## Development & Milestone Status (Backlogs B1–B23)

- [x] **B1:** Database provider decision recorded (PostgreSQL 14+)
- [x] **B2–B3:** Module scope agreed (`master_data`, `profile`, `recruitment`) & ownership matrix defined
- [x] **B4–B5:** Profile entities identified, validated, and normalized
- [x] **B6–B7:** Jobs & Applications entities identified, validated, and normalized
- [x] **B8–B9:** Profile relationships and cardinalities modeled
- [x] **B10–B11:** Jobs & Applications relationships and cardinalities modeled
- [x] **B12–B13:** Profile standard columns, data types, nullability, and sensitivity classes documented
- [x] **B14–B15:** Jobs & Applications columns, data types, nullability, and sensitivity classes documented
- [x] **B16–B17:** Profile logical ER design assembled and reviewed
- [x] **B18–B19:** Recruitment logical ER design assembled and reviewed
- [x] **B20–B21:** Profile PKs, FKs, unique/check constraints, and delete/update behavior specified
- [x] **B22–B23:** Jobs & Applications constraints, triggers, indexes, and final Phase 1 sign-off completed

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
