# Talentra: Formal Requirement Analysis Docket (Step 01)
## Talencia Data-Driven Development Lifecycle — Phase 1: Discover

**System Name:** Talentra Job Search & Demand Management Platform  
**Document Code:** `DOC-TAL-REQ-001`  
**Standard Compliance:** Talencia DDD Lifecycle Step 01 (Gate G1)  
**Lifecycle Status:** Approved & Frozen  
**Platform Scope:** Full Platform (Phase 1 Foundation, Phase 2 Enterprise Tenancy & Gig Marketplace, Phase 3 Sourcing, Licensing & Subscriptions)

---

## 1. Problem Statement & Executive Scope

### 1.1 The Problem
Legacy recruitment and talent discovery platforms suffer from severe structural fragmentation:
1. **Siloed Workforce Categories**: Platforms force separate tools for lateral recruitment, campus placements, and freelance/gig milestones, resulting in disjointed identities and duplicate data.
2. **"Resume Dump" Inefficiencies**: Lack of structured pre-qualification prompts leads to massive volumes of unqualified candidates that flood recruiters.
3. **Data Quality Decay & Security Vulnerabilities**: Plaintext storage of tax identifiers, duplicate phone/email casings, and lack of transaction-safe immutable ledgers invite regulatory breaches under the DPDP Act 2023 and GDPR.
4. **Commercial Leakage**: Traditional systems lack database-level enforcement of seat limits, leading to unauthorized credential sharing across non-paying team members.

### 1.2 System Goals
* Provide an enterprise-grade, high-performance PostgreSQL 16+ data architecture supporting **100,000,000+ candidate profiles** and **10,000,000+ active job requisitions**.
* Guarantee sub-10ms primary key index lookups via 64-bit integer surrogate keys (`bigint GENERATED ALWAYS AS IDENTITY`).
* Enforce 100% of business invariants, state machine transitions, and immutability rules directly within the database engine via declarative constraints and automated triggers.

### 1.3 Out-of-Scope Boundaries (Explicit)
1. **Raw Credit Card / PCI Storage**: Plaintext PAN and CVV numbers are strictly out-of-scope. Delegated to PCI-DSS Level 1 compliant gateway tokenization (`billing.payment_method`).
2. **Direct Video/Binary Streaming**: Video interview streaming is out-of-scope; only structured interview ratings and recording URLs are stored (`recruitment.interview_feedback`).
3. **Application-Layer UI Cache Logic**: Frontend session bundling is out-of-scope; the database handles relational translation (`master_data.ui_translation`) and session tokens (`administration.identity_session`).

---

## 2. Platform Assumptions & Ranked Open Questions

### 2.1 Assumptions
1. Every corporate organization operating on the platform has at least one legal entity registered under national corporate authorities (e.g. MCA, GSTIN, SEC).
2. Users access the platform across varying network conditions in Tier-1, Tier-2, and Tier-3 geographies, necessitating standardized E.164 phone numbers and multilingual UI fallbacks.
3. Financial ledger transactions are strictly append-only; erroneous credit allocations cannot be edited in place and must be adjusted through compensating ledger entries.

### 2.2 Open Questions (Ranked by Design Impact)

| Rank | Question | Impact Level | Architectural Resolution |
| :---: | :--- | :---: | :--- |
| **Q1** | How to prevent circular ownership loops in conglomerate enterprise parent-subsidiary hierarchies? | **Critical** | Resolved via recursive CTE cycle detection trigger `trg_organisation_relationship_cycle` guarded by transaction advisory locks (`pg_advisory_xact_lock`). |
| **Q2** | How to prevent overlapping pricing rates and subscription terms without application race conditions? | **Critical** | Resolved via PostgreSQL 16 `btree_gist` temporal exclusion constraints (`EXCLUDE USING gist (valid_range WITH &&)`). |
| **Q3** | How to enforce finite recruiter seat allocations when an organization has hundreds of employees? | **High** | Resolved via `licence.seat_assignment` with automated quota validation trigger `trg_enforce_seat_cap`. |
| **Q4** | How to balance searchable corporate tax identifiers (GSTIN, PAN) with strict cryptographic privacy? | **High** | Resolved via dual-column envelope encryption: AES-256-GCM ciphertext + HMAC-SHA256 blind deterministic search fingerprint. |

---

## 3. Master Requirements Docket (`REQ-001` to `REQ-035`)

| REQ ID | Requirement Statement | Source (Rule Group / PRD) | Priority | Actor(s) | Ambiguity Resolution & Numeric Metric |
| :--- | :--- | :---: | :---: | :--- | :--- |
| **REQ-001** | Candidate Identity & Email Normalization | Rule Group 1 | Must-Have | Candidate | Email must be stored in canonical lowercase; enforced by `CHECK (email = lower(email))`. Max length 255 chars. |
| **REQ-002** | E.164 International Phone Format | Rule Group 1 | Must-Have | Candidate, Recruiter | Phone numbers must follow E.164 standard regex `^\+[1-9]\d{1,14}$`. Rejects all local or non-standard phone numbers. |
| **REQ-003** | Sequential 64-bit Surrogate Primary Keys | Rule Group 2 | Must-Have | System | Primary keys must use `bigint GENERATED ALWAYS AS IDENTITY`. Prohibits UUID PKs to guarantee sub-10ms B-Tree lookups at 100M rows. |
| **REQ-004** | Fixed Precision Financial Amounts | Rule Group 2 | Must-Have | Recruiter, Admin | Currency values must use `numeric(12,2)` or `numeric(14,2)` accompanied by an ISO 4217 currency code foreign key. Float/Double prohibited. |
| **REQ-005** | Standardized Lookup Architecture | Rule Group 3 | Must-Have | System | All lookup tables must contain `id`, `code` (snake_case regex `^[a-z][a-z0-9_]*$`), `name_key`, `is_active`, and `sort_order`. |
| **REQ-006** | Multilingual Translation with Fallback | Rule Group 4 | Must-Have | Candidate, Recruiter | UI localized strings must resolve in a single indexed query with automatic fallback to English (`en`) if localized key is missing. |
| **REQ-007** | Relational Screening Questionnaires | Rule Group 5 | Must-Have | Recruiter, Candidate | Jobs can attach versioned questionnaires with typed questions (Text, Single Choice, Multiple Choice, Boolean) and predefined option trees. |
| **REQ-008** | Dynamic Application Form Templates | Rule Group 5 | Should-Have | Recruiter | Custom job application forms must reference structured questionnaire definitions with strict foreign key constraints. |
| **REQ-009** | Forensic Audit Trail Immutability | Rule Group 6 | Must-Have | Auditor, System | Status histories, credit ledgers, and audit events must be strictly append-only; `enforce_append_only()` trigger rejects all `UPDATE` and `DELETE` queries. |
| **REQ-010** | DPDP Act 2023 Purpose-Bound Consent | Rule Group 7 | Must-Have | Candidate, Auditor | Purpose-bound consent must record affirmative grant timestamps, IP addresses, user agents, and explicit revocation periods. |
| **REQ-011** | Column-Level Data Sensitivity Tagging | Rule Group 8 | Must-Have | Auditor, System | Every column classified as Public (`Pub`), Internal (`Int`), Personal (`Per`), or Sensitive (`Sen`) with data retention periods. |
| **REQ-012** | Argon2id Credential Storage | Rule Group 8 | Must-Have | System | Plaintext passwords prohibited. Encrypted using Argon2id (RFC 9106) with minimum 16-byte cryptographically secure salt. |
| **REQ-013** | Enterprise Tenant Isolation via RLS | Rule Group 9 | Must-Have | Recruiter, Admin | Multi-tenant tables must enforce Row-Level Security filtered by `app.current_account_id` and `app.current_organisation_id`. |
| **REQ-014** | Zero-Downtime Extensibility & Views | Rule Group 10 | Must-Have | Admin, Executive | No application-layer downtime when adding statuses. Executive KPI views must compute MRR, pipeline funnels, and retention directly. |
| **REQ-015** | Single Live Organisation Account | Phase 2 Docket | Must-Have | Admin | An enterprise organisation can hold at most one active live account; enforced via partial unique index `WHERE (deleted_at IS NULL)`. |
| **REQ-016** | Single Live Headquarters Designation | Phase 2 Docket | Must-Have | Admin | An organisation can have at most one live headquarters location; enforced via partial unique index `WHERE (is_headquarters = true AND deleted_at IS NULL)`. |
| **REQ-017** | Recruiter Assignment Non-Overlap | Phase 2 Docket | Must-Have | Recruiter, Admin | A recruiter cannot have overlapping active assignment periods within the same organization; enforced via `ex_organisation_recruiter_overlap`. |
| **REQ-018** | Tax Identifier Cryptography | Phase 2 Docket | Must-Have | Admin, Auditor | Tax IDs encrypted using AES-256-GCM (`identifier_value_encrypted`) with HMAC-SHA256 blind hex fingerprints for uniqueness checks. |
| **REQ-019** | Acyclic Corporate Relationships | Phase 2 Docket | Must-Have | Admin | Parent-subsidiary relationships must form a directed acyclic graph (DAG); recursive CTE trigger `trg_organisation_relationship_cycle` blocks cycles. |
| **REQ-020** | Monthly Partitioned Audit Trails | Phase 2 Docket | Must-Have | Auditor | Enterprise audit logs (`organisation.audit_event`) partitioned by month (`audit_event_pYYYYMM`) to support high-throughput ingest and retention pruning. |
| **REQ-021** | Freelance Worker Profile & Availability | Phase 2 Docket | Must-Have | Gig Worker | Gig worker availability calendar windows cannot overlap; enforced via `ex_gig_worker_availability_no_overlap`. |
| **REQ-022** | Self-Application Prevention Guard | Phase 2 Docket | Must-Have | System | Gig requisition creators cannot submit bid proposals to their own gigs; enforced via trigger `trg_prevent_self_application`. |
| **REQ-023** | Gig Contract Positions Cap | Phase 2 Docket | Must-Have | Requisitioner | Total active plus completed gig assignments cannot exceed the approved `positions_count`; enforced via trigger `trg_enforce_positions_cap`. |
| **REQ-024** | Consultant Sourcing Job Openness | Phase 3 Docket | Must-Have | Consultant | Requisitions must explicitly flag `open_to_consultants = true` before external consultants can submit sourcing requests; audit logged. |
| **REQ-025** | Consultant Sourcing Approval Gate | Phase 3 Docket | Must-Have | Recruiter, Consultant | Consultants can only create outreach batches or shortlists after the sourcing request has been approved (`accepted`) by the employer. |
| **REQ-026** | Provable Shortlist Provenance | Phase 3 Docket | Must-Have | Recruiter, Consultant | Sourcing shortlist entries must prove lineage back to either an outreach response or an approved consultant sourcing request. |
| **REQ-027** | Effective-Dated Plan Pricing Ranges | Phase 3 Docket | Must-Have | Admin | Subscription plan pricing must not have overlapping effective date ranges for the same currency; enforced via `ex_plan_price_range`. |
| **REQ-028** | Continuous Subscription Period Terms | Phase 3 Docket | Must-Have | Corporate Tenant | Subscription periods for a given licence contract cannot overlap; enforced via `ex_subscription_period_range`. |
| **REQ-029** | Credit Tariff Consistency | Phase 3 Docket | Must-Have | Admin | Feature unit credit costs must not have conflicting effective date ranges; enforced via `ex_credit_tariff_range`. |
| **REQ-030** | Double-Entry Credit Wallet Ledger | Phase 3 Docket | Must-Have | Corporate Tenant | Credit transactions must be append-only with signed amounts; real-time balance cache synchronized via trigger `trg_wallet_balance_cache_sync`. |
| **REQ-031** | Profile Download Single-Funding Guard | Phase 3 Docket | Must-Have | Recruiter | Every successful candidate profile download must link to exactly one funding source: `wallet_ledger_id` OR `entitlement_usage_id`. |
| **REQ-032** | Transactional Cumulative Refund Cap | Phase 3 Docket | Must-Have | Admin, System | Total non-failed refunds cannot exceed the captured payment transaction amount; enforced via transaction row lock `SELECT ... FOR UPDATE`. |
| **REQ-033** | Named Recruiter Seat Assignment | Phase 3 Expansion | Must-Have | Account Admin | A user can hold at most one active recruiter seat per licence; enforced via partial unique index `idx_seat_assignment_active_user`. |
| **REQ-034** | Automatic Recruiter Seat Cap | Phase 3 Expansion | Must-Have | System | Trigger `trg_enforce_seat_cap` blocks seat allocation if active seats exceed the subscription plan's entitlement quota (`recruiter_seats`). |
| **REQ-035** | Hardware Device Telemetry Binding | Phase 3 Expansion | Must-Have | System, Security | Hardware device fingerprints stored as SHA-256 hashes (`bytea`); partial unique index prevents simultaneous multi-device credential abuse. |

---

## 4. Verification & Gate G1 Compliance Matrix

Every single requirement listed above traces to an exact physical table, a database-level constraint/trigger, and an automated regression test:

```text
Requirement (REQ-xxx) ──> Physical Entity ──> Database Invariant / Trigger ──> Automated Test
     REQ-001          ──> user_account    ──> CHECK (lower(email))         ──> TC-ADM-001
     REQ-017          ──> recruiter       ──> EXCLUDE USING gist           ──> TC-ORG-003
     REQ-019          ──> relationship    ──> trg_organisation_relationship──> TC-ORG-005
     REQ-022          ──> gig_application ──> trg_prevent_self_application ──> GIG-002
     REQ-027          ──> plan_price      ──> ex_plan_price_range          ──> SUB-001
     REQ-032          ──> refund          ──> trg_refund_cap               ──> SUB-004
     REQ-034          ──> seat_assignment ──> trg_enforce_seat_cap         ──> LIC-002
```

**Quality Gate G1 ("Problem Understood"): 100% Verified and Documented.**
