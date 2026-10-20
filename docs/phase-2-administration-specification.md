# Talentra: Phase 2 Administration & Identity Specification Document

**Platform:** Talentra — Job Search & Demand Management Platform  
**Phase:** Phase 2 (Common Modules: Administration & Identity)  
**Deliverables:** Backlogs B24 (Entities), B27 (Relationships), B30 (Columns), B33 (Keys, Constraints, RBAC, Audit)  
**Database Engine:** PostgreSQL 14+  
**Target Schema:** `administration`  
**Conforming to:** Talentra PRD Data Standards (Rule Groups 1 to 10) & Phase 2 Finalization Addendum  

---

## 1. Executive Summary & Scope Boundary

The Administration module serves as the platform-wide identity, authentication metadata, role-based authorization (RBAC), session management, and forensic security foundation.

### In Scope for Administration (Member A):
1. **User Identity & Lifecycle:** Core `user_account` record, verification timestamps, and account status management (`pending_verification`, `active`, `suspended`, `locked`, `closed`).
2. **Credential Security:** Argon2id password hashes and OAuth/OIDC federated subject mappings in `user_credential` (never plaintext or reversible encryption).
3. **RBAC Authorization:** Stable platform roles (`role`), atomic capabilities (`permission`), temporal user-role assignments (`user_role`), and role-permission matrices (`role_permission`).
4. **Session Management:** Hashed opaque session tokens (`bytea`), IP addresses, user agents, throttled activity timestamps, and revocation state tracking in `identity_session`.
5. **Consent & Privacy Evidence:** Append-only DPDP Act 2023 / GDPR consent records (`consent_record`).
6. **Forensic Audit:** Append-only `audit_event` ledger recording actor, action, object, outcome, request ID, and metadata.
7. **Directional Blocking:** `user_block` (candidate blocking employer/recruiter/consultant) and reserved `organisation_block`.
8. **Phase 1 Bridge:** Controlled foreign key integration connecting `profile.candidate_profile.user_id` to `administration.user_account.id`.

### Explicitly Deferred to Other Modules / Later Phases:
* **Organisation Hierarchy & Recruiter-Company Assignment:** Owned by Member B.
* **Gig Contracts, Handoffs & Milestones:** Owned by Member C.
* **Atomic Device Caps & Licences:** Phase 3 implementation.

---

## 2. Nonlinear Entity Map (Backlog B24)

```text
Administration / Identity
 ├── 1. Principal Identity
 │    ├── user_account       -> Canonical login identifier, lifecycle, verification
 │    └── user_credential    -> Argon2id password hash or federated identity provider linkage
 ├── 2. Authorization (RBAC)
 │    ├── role               -> Platform roles (super_admin, admin, candidate, recruiter, etc.)
 │    ├── permission         -> Atomic resource:action capabilities (e.g. audit.read, user.suspend)
 │    ├── user_role          -> Temporal user assignments with valid_from/valid_until and revocation
 │    └── role_permission    -> Many-to-many role to permission matrix
 ├── 3. Identity Sessions
 │    └── identity_session   -> Authenticated sessions, bytea token hashes, expiry, and IP/UA telemetry
 ├── 4. Consent & Privacy Evidence
 │    └── consent_record     -> Append-only grant/withdrawal records per purpose and notice version
 ├── 5. Forensic Audit Evidence
 │    └── audit_event        -> Append-only security and access event ledger
 └── 6. Blocking & Visibility Policy
      ├── user_block         -> Directional user-to-user blocking (self-block forbidden)
      └── organisation_block -> User-to-organisation blocking integration contract
```

---

## 3. Relationship Model & Cardinalities (Backlog B27)

| Parent Entity | Child Entity | Cardinality | Implementation & Integrity Rule |
| :--- | :--- | :---: | :--- |
| `user_account` | `user_credential` | `1 to 0..N` | Multiple credentials per user across history; partial unique index enforces at most one active password credential per account. `ON DELETE RESTRICT`. |
| `user_account` | `user_role` | `1 to 0..N` | Temporal assignment. Partial unique index prevents duplicate active grants of the same role. `ON DELETE RESTRICT`. |
| `role` | `user_role` | `1 to 0..N` | Roles assigned across multiple accounts. System roles protected from hard deletion. `ON DELETE RESTRICT`. |
| `role` | `role_permission` | `1 to 0..N` | Many-to-many permission assignment to roles. `ON DELETE RESTRICT`. |
| `permission` | `role_permission` | `1 to 0..N` | Permissions mapped across multiple roles. `ON DELETE RESTRICT`. |
| `user_account` | `identity_session` | `1 to 0..N` | User can hold concurrent sessions. Expired or revoked sessions fail authorization. `ON DELETE RESTRICT`. |
| `user_account` | `consent_record` | `1 to 0..N` | Append-only. Withdrawal creates a new row. `ON DELETE RESTRICT`. |
| `user_account` | `audit_event` (actor) | `1 to 0..N` | Nullable for unauthenticated failures, background jobs, or system events. `ON DELETE RESTRICT`. |
| `user_account` | `user_block` (blocker) | `1 to 0..N` | Blocker initiates directional block. `blocker_user_id <> blocked_user_id`. `ON DELETE RESTRICT`. |
| `user_account` | `user_block` (blocked) | `1 to 0..N` | Blocked party denied visibility to blocker's profile. `ON DELETE RESTRICT`. |
| `user_account` | `candidate_profile` | `1 to 0..1` | **Phase 1 Bridge:** Reconciled via `user_account.id = 1001` before FK constraint attachment (`ON DELETE SET NULL`). |

---

## 4. Column Data Dictionary & Classifications (Backlog B30)

All columns are classified under Rule Group 6: `Public`, `Internal`, `Personal`, or `Sensitive`.

### 4.1 `administration.user_account`
| Column | Type | Nullable? | Class | Rationale & Constraint |
| :--- | :--- | :---: | :---: | :--- |
| `id` | `bigint IDENTITY` | No | Internal | Surrogate primary key. |
| `email` | `varchar(254)` | No | Personal | Canonical login identifier; lowercase check (`email = lower(email)`), permanently unique for v1. |
| `email_verified_at`| `timestamptz` | Yes | Personal | Null until user confirms email ownership via verification token. |
| `phone_e164` | `varchar(16)` | Yes | Personal | E.164 phone format check (`^\+[1-9][0-9]{1,14}$`). |
| `phone_country_code`| `varchar(10)` | Yes | Personal | Companion prefix code; null when phone is omitted. |
| `phone_verified_at`| `timestamptz` | Yes | Personal | Null until SMS/voice OTP verification completes. |
| `display_name` | `varchar(150)` | Yes | Personal | Optional UI display name; full candidate name lives in profile schema. |
| `account_status_code`| `varchar(30)` | No | Internal | Default `'active'`; controlled by check (`pending_verification`, `active`, `suspended`, `locked`, `closed`). |
| `last_authenticated_at`| `timestamptz`| Yes | Internal | Null prior to initial successful authentication. |
| `closed_at` | `timestamptz` | Yes | Internal | Null unless account undergoes formal closure workflow. |
| `created_at` / `updated_at` | `timestamptz` | No | Internal | Automated audit timestamps maintained via database triggers. |
| `deleted_at` | `timestamptz` | Yes | Internal | Soft-delete timestamp. |

### 4.2 `administration.user_credential`
| Column | Type | Nullable? | Class | Rationale & Constraint |
| :--- | :--- | :---: | :---: | :--- |
| `id` | `bigint IDENTITY` | No | Internal | Surrogate primary key. |
| `user_account_id` | `bigint` | No | Internal | Owner account reference. `ON DELETE RESTRICT`. |
| `credential_type_code`| `varchar(30)` | No | Internal | Checked values: `'password'`, `'oidc'`, `'saml'`, `'magic_link'`. |
| `password_hash` | `text` | Yes | Sensitive | Argon2id cryptographic hash only. Never plaintext. Null for federated accounts. |
| `identity_provider_code`| `varchar(80)` | Yes | Internal | Provider identifier (`google`, `linkedin`, `github`); required for federated credentials. |
| `provider_subject`| `varchar(255)` | Yes | Sensitive | Opaque federated subject ID; unique per provider. |
| `is_active` | `boolean` | No | Internal | Default `true`; inactive credentials cannot authenticate. |

### 4.3 `administration.identity_session`
| Column | Type | Nullable? | Class | Rationale & Constraint |
| :--- | :--- | :---: | :---: | :--- |
| `id` | `bigint IDENTITY` | No | Internal | Surrogate primary key. |
| `user_account_id` | `bigint` | No | Internal | Authenticated user reference. `ON DELETE RESTRICT`. |
| `session_token_hash`| `bytea` | No | Sensitive | SHA-256 hash of random opaque token. Clear token shown once to client and never stored. |
| `session_status_code`| `varchar(20)` | No | Internal | Default `'active'`; checked (`active`, `revoked`, `expired`). |
| `started_at` | `timestamptz` | No | Internal | Session start timestamp. |
| `last_activity_at` | `timestamptz` | No | Internal | Throttled activity timestamp. |
| `expires_at` | `timestamptz` | No | Internal | Hard session expiration. Check `expires_at > started_at`. |
| `ended_at` | `timestamptz` | Yes | Internal | Null while active; set on logout or revocation. Check `ended_at >= started_at`. |
| `revoke_reason_code`| `varchar(40)` | Yes | Internal | Reason for session termination (`logout`, `admin_revoke`, `password_reset`, `security_event`). |
| `source_ip` | `inet` | Yes | Personal | Client network address; access-controlled. |
| `user_agent` | `varchar(512)` | Yes | Internal | Client browser/app user-agent string. |

---

## 5. Security & RBAC Access Policy (Backlog B33)

### 5.1 Platform Role Matrix
1. **`super_admin`:** Unrestricted administrative capabilities, role grants, security audits, and break-glass operations.
2. **`admin`:** Routine operations, support management, and non-elevated user administration.
3. **`account_admin`:** Organisation-scoped administrative tasks.
4. **`candidate`:** Manages own candidate profile, applications, assessments, resumes, and blocking rules.
5. **`employer`:** Corporate hiring authority; owns job requisitions.
6. **`recruiter`:** Candidate outreach, pipeline staging, and interview management for assigned jobs.
7. **`consultant`:** Third-party sourcing restricted strictly to requisitions marked `is_open_to_consultants = true`.
8. **`placement_officer`:** Institutional campus placement coordinator.
9. **`guest`:** Public catalog exploration.

### 5.2 Directional Candidate Blocking Policy
```sql
-- Evaluated before returning candidate profiles to recruiters/employers
WHERE NOT EXISTS (
    SELECT 1 FROM administration.user_block ub
    WHERE ub.blocker_user_id = candidate_profile.user_id
      AND ub.blocked_user_id = :current_viewer_user_id
      AND ub.lifted_at IS NULL
)
```
* **Unilateral:** If Candidate A blocks Recruiter B, Recruiter B is denied access. Blocking is directional and not automatically reciprocal.
* **Self-Blocking Prohibited:** Database check constraint `chk_user_block_not_self` rejects `blocker_user_id = blocked_user_id`.
* **Idempotent Active Blocks:** Partial unique index `(blocker_user_id, blocked_user_id) WHERE lifted_at IS NULL` prevents duplicate active blocks while preserving historical lifted records.

---

## 6. Verification & Regression Test Suite

All 24 test scenarios (`ADM-001` through `ADM-024`) from the Addendum are codified in [`sql/administration_regression_test.sql`](file:///c:/Users/hp/OneDrive/Desktop/talencia1/talentra-database-design/sql/administration_regression_test.sql):

* **Email Invariant:** Verified that mixed-case emails are rejected by check constraint.
* **Credential Secrecy:** Verified that plaintext passwords never enter the database.
* **Identity Lifecycle:** Verified that invalid/suspended/closed accounts cannot authorize.
* **RBAC Allow & Deny:** Verified candidate permissions succeed while administrative calls are rejected.
* **Append-Only Immutability:** Verified that `UPDATE` and `DELETE` on `audit_event` and `consent_record` raise hard database exceptions.
* **Session Invariants:** Verified that expired sessions and inconsistent states are blocked.
* **Phase 1 Bridge:** Verified that `candidate_profile.user_id` correctly resolves to `user_account(id)` and rejects nonexistent IDs.
