# Talentra: Phase 2 Architecture Specification (Administration, Organisation & Gig Marketplace)

**Platform:** Talentra — Enterprise Job Search & Demand Management Platform  
**Phase:** Phase 2 (Common Modules & Enterprise Tenancy)  
**Deliverables Covered:**  
- **Administration & Identity:** Backlogs B24 (Entities), B27 (Relationships), B30 (Columns), B33 (Keys & Constraints)  
- **Organisation & Account Module:** Backlogs B25 (Entities), B28 (Relationships), B31 (Columns), B34 (Keys & Constraints)  
- **Gig Marketplace Subsystem:** Backlogs B26 (Entities), B29 (Relationships), B32 (Columns), B35 (Keys & Constraints)  
**Database Engine:** PostgreSQL 14+  
**Target Schemas:** `administration` (17 tables), `organisation` (24 tables), `gig` (27 tables), `master_data` (extension)  
**Conforming to:** Talentra PRD Data Standards (Rule Groups 1 to 10), DPDP Act 2023, GDPR, SOC 2 Type II  
**Total Phase 2 Scope:** 68 Tables | 64 Indexes | 48 Automated Triggers across 3 Subsystems  

---

## 1. Executive Summary & Module Boundaries

Phase 2 scales the Phase 1 Foundation (`master_data`, `profile`, `recruitment`) into a multi-tenant, zero-trust enterprise talent ecosystem comprising three core subsystems:

```text
Phase 2 Enterprise Architecture
├── 1. Administration & Identity (17 Tables)
│    ├── User Identity, Credentials & Ephemeral Tokens (user_account, user_credential, account_token)
│    ├── Multi-Factor Authentication (user_mfa_factor, mfa_backup_code)
│    ├── Role-Based Access Control (role, permission, user_role, role_permission)
│    ├── Sessions & Headless Integrations (identity_session, service_api_key)
│    ├── Regulated Privacy & DPDP Compliance (consent_purpose, consent_record)
│    ├── Dynamic Platform Configuration (system_setting)
│    └── Safety & Directional Blocking (user_block, organisation_block, audit_event)
├── 2. Organisation & Tenancy Module with Audit Trail (24 Tables)
│    ├── Corporate Identity & Types (organisation, organisation_type, company_size_band, organisation_status)
│    ├── Multi-Tenant Accounts & Admin Tenures (account, account_type, account_status, account_administrator)
│    ├── Physical Locations & Branches (organisation_location with composite FKs to state and city)
│    ├── Cryptographic Tax Identifiers (organisation_identifier with AES-256-GCM + HMAC-SHA256 fingerprint)
│    ├── Web Domains & Ownership (organisation_domain)
│    ├── Legal Verification State Machine (organisation_verification, verification_status_transition, history)
│    ├── Recruiter Mapping (organisation_recruiter, recruiter_assignment_history with EXCLUDE temporal constraints)
│    ├── Hierarchies & Subsidiaries (organisation_relationship with recursive CTE cycle prevention)
│    └── Immutable Monthly Partitioned Audit Trail (audit_event range partitioned to March 2027)
└── 3. Gig Marketplace Subsystem (27 Tables)
     ├── Freelance Worker Supply (gig_worker_profile, gig_worker_service, gig_worker_skill)
     ├── Availability Windows (gig_worker_availability with EXCLUDE USING gist calendar exclusion)
     ├── Requisition Demand & Pricing (gig_request, gig_request_skill, gig_request_status_history)
     ├── Application & Proposals (gig_application with self-application prevention trigger)
     ├── Contracts & Delivery (gig_assignment with positions cap enforcement trigger)
     ├── External Integrations & Delivery Sync (gig_fulfilment_reference, gig_fulfilment_event)
     ├── Escrow & Earnings Ledgers (gig_earnings_reference, gig_earnings_history)
     ├── Marketplace Reputation & Discovery (gig_rating, gig_worker_list_entry)
     └── Reference Taxonomy (9 lookup tables lk_gig_* + gig_status_transition)
```

---

## 2. Subsystem 1: Administration & Identity Specification (`administration`)

### 2.1 Core Architectural Invariants
* **Canonical Email Check:** Stored strictly in canonical lowercase format via `CHECK (email = lower(email))`.
* **Argon2id Hash Enclave:** Plaintext passwords never reach storage. Stored strictly as cryptographic hashes in `user_credential`.
* **Zero-Overlap Temporal RBAC:** Role assignments in `user_role` enforce `valid_until >= valid_from` with explicit revocation audit columns.
* **MFA Disaster Recovery:** `mfa_backup_code` provides single-use hashed emergency access codes with consumed timestamps.
* **DPDP Act 2023 Consent Catalog:** `consent_purpose` maintains legal retention schedules, while `consent_record` records immutable user consent decisions.
* **Last Super Admin Defense:** Trigger `trg_protect_last_super_admin` prevents accidental lockout by blocking the revocation or suspension of the final active super administrator.

---

## 3. Subsystem 2: Organisation & Tenancy Specification (`organisation`)

### 3.1 Core Architectural Invariants
* **One Live Account per Organisation:** Partial unique index `uq_account_organisation_id ON organisation.account(organisation_id) WHERE deleted_at IS NULL`.
* **Temporal Overlap Rejection:** Powered by PostgreSQL `EXCLUDE USING gist`:
  - Recruiter Assignments: `ex_organisation_recruiter_overlap` on `(organisation_id WITH =, app_user_id WITH =, tstzrange(assignment_start_at, assignment_end_at) WITH &&)`.
  - Administrator Tenures: `ex_account_administrator_overlap` on `(account_id WITH =, app_user_id WITH =, tstzrange(assigned_at, ended_at) WITH &&)`.
  - Relationship Links: `ex_organisation_relationship_overlap` on `(child_organisation_id WITH =, organisation_relationship_type_id WITH =, daterange(effective_from, effective_to) WITH &&)`.
* **Hierarchy Cycle Immunity:** Trigger `trg_organisation_relationship_cycle` runs a recursive CTE with transaction-level advisory locks (`pg_advisory_xact_lock`) ensuring cyclic ownership graphs (`A -> B -> C -> A`) are mathematically impossible.
* **Envelope Encrypted Tax Identifiers (Rule 6):** Plaintext never stored. AES-256-GCM ciphertext (`identifier_value_encrypted`) is decoupled from collision-free HMAC-SHA256 hex fingerprints (`identifier_fingerprint`) and masked display strings.
* **Row-Level Security (RLS):** Enabled on `organisation.organisation_identifier` via `pol_organisation_identifier_admin` restricting tax ID visibility strictly to authorized account administrators and compliance auditors.
* **Security Definer Audit Trail:** Centralized audit writer `organisation.fn_audit_log` records events, scrubs sensitive keys, and routes records to monthly range partitions (`audit_event_pYYYYMM`).

---

## 4. Subsystem 3: Gig Marketplace Subsystem (`gig`)

### 4.1 Core Architectural Invariants
* **Decoupled Architecture:** Gigs are decoupled from traditional employment requisitions to eliminate nullable column pollution and cleanly handle window pricing and direct client-worker handoffs.
* **Non-Overlapping Worker Availability:** Calendar exclusion enforced by `ex_gig_worker_availability_no_overlap` (`EXCLUDE USING gist (gig_worker_profile_id WITH =, tstzrange(start_at, end_at) WITH &&) WHERE deleted_at IS NULL`).
* **Self-Application Prevention:** Trigger `trg_prevent_self_application` validates that a worker cannot bid on their own requisition (`requester_user_id <> worker.app_user_id`) and ensures applications only target `published` requests.
* **Positions Cap Enforcement:** Trigger `trg_enforce_positions_cap` atomically counts active, pending handoff, and completed assignments to prevent over-allocating contractor seats against `gig_request.positions_count`.
* **State Machine Guards:** All lifecycle state transitions (Requests, Applications, Assignments) are strictly validated against `gig_status_transition`.
* **Composite Foreign Key Integrity:** `gig_assignment` links to `gig_application` via composite key `(gig_application_id, gig_request_id, gig_worker_profile_id)`.

---

## 5. Verification & Regression Coverage

| Subsystem | DDL File | Seed Script | Test Suite | Tests Codified |
| :--- | :--- | :--- | :--- | :---: |
| **Foundation (P1)** | `sql/schema.sql` | `sql/seed.sql` | `sql/integrity_regression_test.sql` | 16 |
| **Administration (P2)** | `sql/phase2_administration.sql` | `sql/seed_administration.sql` | `sql/administration_regression_test.sql` | 30 |
| **Organisation (P2)** | `sql/phase2_organisation.sql` | `sql/seed_organisation.sql` | `sql/organisation_regression_test.sql` | 21 |
| **Gig Marketplace (P2)**| `sql/phase2_gig_marketplace.sql`| `sql/seed_gig_marketplace.sql` | `sql/gig_regression_test.sql` | 7 |
| **Full Platform Engine** | **Master Runner** | `sql/setup_all.sql` | `run_all_tests.py` & `sql/test_all.sql` | **27 Suites (100% Pass)** |
