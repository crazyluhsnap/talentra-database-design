# Talentra Phase 5: Comprehensive Security Design Note & STRIDE Threat Model (Milestones 22 & 23 - B75 to B79, B81)

**Platform:** Talentra Enterprise Job Search and Demand Management Platform  
**Target Engine:** PostgreSQL 16+ Enterprise  
**Author:** Talentra Information Security & Data Protection Architecture Team  
**Standards Compliance:** ISO/IEC 27001, DPDP Act 2023, GDPR, PCI-DSS Level 1 (Integration Boundary)  
**Status:** APPROVED & AUDITED  

---

## 1. Module-Specific PII Handling & Cryptographic Design (B75–B77)

### 1.1 Administration, Organisation & Gig Marketplace (B75 - Member A)
* **Candidate & User Contact Details (`user_account`, `candidate_profile`):**
  - **Phone Numbers:** Stored in E.164 canonical format (`^\+[1-9]\d{1,14}$`). At rest, secondary contact phone numbers and personal emails are encrypted using **AES-256-GCM** with per-tenant DEKs (Data Encryption Keys).
  - **Blind Index Fingerprints:** To enable deterministic unique lookups without decrypting the entire database table, a blind index using **HMAC-SHA256** with an isolated cryptographic pepper is stored in `phone_blind_index`.
* **Corporate Tax Identifiers & National IDs (`organisation_identifier`, `identity_verification`):**
  - **Raw National Identifiers (PAN, GSTIN, SSN, Aadhaar):** Clear-text storage is strictly prohibited. The database stores:
    1. `identifier_value_encrypted bytea`: AES-256-GCM ciphertext.
    2. `identifier_blind_index bytea`: HMAC-SHA256 hash for exact-match uniqueness checks.
    3. `verification_token text`: Ephemeral verification token issued by the external KYC provider.

### 1.2 Licences, Sourcing & Subscriptions / Wallet (B76 - Member B)
* **Payment Credentials & Bank References (`billing.payment_method`, `billing.payment_transaction`):**
  - **Card Data (PAN / CVV):** Strictly out-of-scope; never enters platform boundaries (PCI-DSS compliant delegation).
  - **Gateway Reference Tokens:** Stored as vendor-scoped gateway tokens (`stripe_pm_*`, `razorpay_tok_*`).
  - **Bank Account References:** Masked on ingestion (e.g. `****-****-1234`).
* **Authentication Credentials (`administration.user_credential`):**
  - **Password Storage:** Plaintext or single-iteration hashes (MD5, SHA1, plain SHA256) are prohibited by schema check constraints.
  - **Argon2id Specification:** RFC 9106 Argon2id with memory cost $m=65536$ (64MB), time cost $t=3$ iterations, parallelism $p=4$, and 16-byte random salt. Format enforced via regex check constraint: `^(\$argon2id\$v=19\$m=.*)`.
  - **Reset Tokens (`credential_reset_token`):** Stored as SHA-256 binary digest with strict expiration (`expires_at > now()`) and single-use invalidation (`consumed_at IS NULL`).

### 1.3 Notifications, Analytics, Community & Shared Governance (B77 - Member C)
* **Notification Destinations & Dynamic Masking (`engagement.notification_delivery`):**
  - Deliveries store only masked destinations (`destination_masked text`):
    - Email: `a***v@example.com`
    - Phone: `+91*****4512`
  - Eliminates exposure of candidate contacts to operational engineers inspecting notification queues.
* **Analytical Anonymisation & Small-Cell Masking (`analytics` Schema):**
  - **Pseudonymisation:** Natural keys are stripped; all candidate dimensions and facts identify candidates using a salted SHA-256 keyed hash (`candidate_pseudonym`).
  - **Small-Cell Suppression:** Profile view queries and demographic aggregates enforce k-anonymity; any cell representing fewer than 10 individuals is masked (`-1` or `SUPPRESSED`).
* **DPDP Act 2023 Purpose-Bound Consent (`administration.user_consent`):**
  - Explicit affirmative consent records tied to versioned `consent_policy`. Revocation sets `revoked_at` and automatically halts notification and profile discovery pipelines.

---

## 2. Platform STRIDE Threat Model & Defense Matrix (B78)

| Threat Category | Potential Attack Vector | Impact | Schema & Database-Level Defense Controls |
| :--- | :--- | :---: | :--- |
| **Spoofing** | Forged recruiter credentials or session hijacking | Critical | • Argon2id password hashing.<br>• Hardware device fingerprint binding in `licence.registered_device`.<br>• Concurrency-safe session eviction (`administration.start_user_session()`). |
| **Tampering** | Illicit credit ledger inflation or altered application stages | Critical | • Append-only database triggers (`enforce_append_only()`) blocking `UPDATE` and `DELETE`.<br>• Double-entry wallet ledgers with real-time balance cache triggers.<br>• Application status history immutability. |
| **Repudiation** | Recruiter denying candidate rejection or admin denying seat revokes | High | • Immutable audit trail (`administration.system_audit_log`, `organisation.audit_event`).<br>• Records actor `user_account_id`, IP address (`inet`), timestamp, and JSON before/after state diff. |
| **Information Disclosure** | Recruiter viewing blocked candidates or corporate tax numbers | Critical | • PostgreSQL Security Definer function `administration.candidate_visible_to()` automatically filtering blocked candidates.<br>• AES-256-GCM envelope encryption on tax IDs.<br>• Row-Level Security (RLS) on multi-tenant tables. |
| **Denial of Service** | Credential stuffing, session resource exhaustion, queue floods | High | • Monthly partitioned login attempt tables with failed threshold lockouts.<br>• `SKIP LOCKED` worker queues preventing transaction deadlocks.<br>• Database-enforced device limits per licence. |
| **Elevation of Privilege** | Recruiter updating company billing or candidate modifying test scores | Critical | • Relational RBAC matrix with `role`, `permission`, `role_permission`, `user_role`.<br>• Database check constraints and triggers verifying actor role before committing state changes. |

---

## 3. Forensic Access Control & Security Verification (B79)

The platform's access control and security guarantees are codified and validated through the automated regression test suite `sql/phase5_security_regression_test.sql`:

1. **Candidate Blocking Enforcement (`candidate_visible_to`):**
   - When Candidate A blocks Recruiter B, any search or profile lookup executed by Recruiter B returns `false` or excludes Candidate A from the result set.
   - When Candidate A blocks Organisation C, all recruiters assigned to Organisation C are excluded from viewing Candidate A.
2. **Append-Only Immutability:**
   - Attempted `UPDATE` on `system_audit_log`, `wallet_ledger`, or `application_status_history` raises a database exception (`cannot update immutable record`).
   - Attempted `DELETE` raises a database exception (`cannot delete immutable record`).
3. **Concurrent Session & Device Limit Locking:**
   - `start_user_session()` locks the user's active sessions with `FOR UPDATE`. If active sessions equal `max_devices_per_user`, either the oldest session is atomically terminated or the new login attempt is rejected, preventing simultaneous credential abuse.

---

## 4. Security Sign-Off Summary (B81)

The Talentra platform security architecture enforces security at the **data and storage tier**, guaranteeing defense-in-depth even if application servers are compromised.
