-- ============================================================================
-- Talentra: Phase 2 Administration Seed & Identity Reconciliation
-- Populates: Platform roles, atomic permissions, role-permission matrix,
-- system administrator, recruiter account, and reconciles Phase 1 candidate (id=1001).
-- Attaches the Phase 1 cross-module candidate_profile foreign key safely.
-- ============================================================================

BEGIN;

-- ----------------------------------------------------------------------------
-- 1. SEED SYSTEM ROLES (Idempotent)
-- ----------------------------------------------------------------------------
INSERT INTO administration.role (code, display_name, description, is_system_role, is_active)
VALUES 
    ('super_admin', 'Super Administrator', 'Full platform control, role management, security audits, break-glass recovery', true, true),
    ('admin', 'Platform Administrator', 'Routine operations, user administration, support management', true, true),
    ('account_admin', 'Account Administrator', 'Organisation-level administrative actions and user management', true, true),
    ('guest', 'Anonymous Guest', 'Public catalog, landing pages, and unauthenticated job exploration', true, true),
    ('candidate', 'Candidate Jobseeker', 'Manages own profile, applications, assessments, and blocking rules', true, true),
    ('employer', 'Employer Organisation', 'Corporate hiring authority, job requisition owner', true, true),
    ('recruiter', 'Corporate Recruiter', 'Sourcing candidates, pipeline operations, interview scheduling', true, true),
    ('consultant', 'External Consultant', 'Third-party recruiter for open-to-consultant requisitions', true, true),
    ('placement_officer', 'Training & Placement Officer', 'Campus placement coordinator and cohort administrator', true, true)
ON CONFLICT (code) DO UPDATE 
SET display_name = EXCLUDED.display_name,
    description = EXCLUDED.description,
    is_active = true;

-- ----------------------------------------------------------------------------
-- 2. SEED ATOMIC PERMISSIONS
-- ----------------------------------------------------------------------------
INSERT INTO administration.permission (code, resource_code, action_code, description)
VALUES
    -- User & Account Permissions
    ('user.create', 'user', 'create', 'Register new user account'),
    ('user.read_self', 'user', 'read_self', 'View own user account profile'),
    ('user.update_self', 'user', 'update_self', 'Update own user account profile'),
    ('user.suspend', 'user', 'suspend', 'Suspend user account access'),
    ('user.close', 'user', 'close', 'Close or soft-delete user account'),
    ('role.assign', 'role', 'assign', 'Assign roles to user accounts'),
    ('role.revoke', 'role', 'revoke', 'Revoke assigned roles from user accounts'),

    -- Candidate Profile Permissions
    ('candidate_profile.read_own', 'candidate_profile', 'read_own', 'Read own candidate profile and documents'),
    ('candidate_profile.update_own', 'candidate_profile', 'update_own', 'Update own candidate profile and documents'),
    ('candidate_profile.search', 'candidate_profile', 'search', 'Search candidate database for recruiting'),
    ('candidate_profile.view_full', 'candidate_profile', 'view_full', 'Unlock and view full contact info (credit-deducted)'),

    -- Job Requisition Permissions
    ('job_requirement.create', 'job_requirement', 'create', 'Draft new job requirements'),
    ('job_requirement.publish', 'job_requirement', 'publish', 'Publish job requirement to active marketplace'),
    ('job_requirement.read_all', 'job_requirement', 'read_all', 'Read all published job requirements'),
    ('job_requirement.update_assigned', 'job_requirement', 'update_assigned', 'Update job requirements assigned to own company'),

    -- Application & Pipeline Permissions
    ('job_application.apply', 'job_application', 'apply', 'Submit application to a job requirement'),
    ('job_application.view_own', 'job_application', 'view_own', 'View status of own submitted job applications'),
    ('job_application.advance_pipeline', 'job_application', 'advance_pipeline', 'Move application stages and schedule interviews'),

    -- Audit & Security Permissions
    ('audit.read', 'audit_event', 'read', 'Query security and compliance audit event logs'),
    ('audit.export', 'audit_event', 'export', 'Export audit logs for external regulatory examination'),
    ('block.manage', 'user_block', 'manage', 'Create and lift user and organization blocking rules')
ON CONFLICT (code) DO NOTHING;

-- ----------------------------------------------------------------------------
-- 3. ROLE-PERMISSION MATRIX
-- ----------------------------------------------------------------------------
-- Super Admin gets all permissions
INSERT INTO administration.role_permission (role_id, permission_id)
SELECT r.id, p.id
FROM administration.role r CROSS JOIN administration.permission p
WHERE r.code = 'super_admin'
ON CONFLICT (role_id, permission_id) DO NOTHING;

-- Candidate permissions
INSERT INTO administration.role_permission (role_id, permission_id)
SELECT r.id, p.id
FROM administration.role r 
CROSS JOIN administration.permission p
WHERE r.code = 'candidate' 
  AND p.code IN (
      'user.read_self', 'user.update_self', 
      'candidate_profile.read_own', 'candidate_profile.update_own', 
      'job_requirement.read_all', 'job_application.apply', 
      'job_application.view_own', 'block.manage'
  )
ON CONFLICT (role_id, permission_id) DO NOTHING;

-- Recruiter permissions
INSERT INTO administration.role_permission (role_id, permission_id)
SELECT r.id, p.id
FROM administration.role r 
CROSS JOIN administration.permission p
WHERE r.code = 'recruiter' 
  AND p.code IN (
      'user.read_self', 'candidate_profile.search', 'candidate_profile.view_full',
      'job_requirement.read_all', 'job_requirement.update_assigned',
      'job_application.advance_pipeline', 'block.manage'
  )
ON CONFLICT (role_id, permission_id) DO NOTHING;

-- ----------------------------------------------------------------------------
-- 4. RECONCILIATION OF PHASE 1 CANDIDATE (user_id = 1001)
-- Reconciles Aarav Sharma so the profile.candidate_profile FK can be wired!
-- ----------------------------------------------------------------------------
INSERT INTO administration.user_account (
    id, email, email_verified_at, phone_e164, phone_country_code, 
    phone_verified_at, display_name, account_status_code
)
OVERRIDING SYSTEM VALUE
VALUES (
    1001,
    'aarav.sharma@example.com',
    CURRENT_TIMESTAMP,
    '+919876543210',
    '+91',
    CURRENT_TIMESTAMP,
    'Aarav Sharma',
    'active'
)
ON CONFLICT (email) DO UPDATE 
SET display_name = EXCLUDED.display_name,
    account_status_code = 'active';

-- Attach candidate password credential (Argon2id simulated hash)
INSERT INTO administration.user_credential (
    user_account_id, credential_type_code, password_hash, is_active
)
SELECT 1001, 'password', '$argon2id$v=19$m=65536,t=3,p=4$c29tZXNhbHQ$dGVzdGhhc2hmaXh0dXJlMTIzNDU2Nzg5MA', true
WHERE NOT EXISTS (
    SELECT 1 FROM administration.user_credential 
    WHERE user_account_id = 1001 AND credential_type_code = 'password'
);

-- Assign candidate role to Aarav Sharma
INSERT INTO administration.user_role (user_account_id, role_id)
SELECT 1001, r.id
FROM administration.role r WHERE r.code = 'candidate'
ON CONFLICT DO NOTHING;

-- ----------------------------------------------------------------------------
-- 5. SEED PLATFORM SUPER_ADMIN (id = 1000)
-- ----------------------------------------------------------------------------
INSERT INTO administration.user_account (
    id, email, email_verified_at, display_name, account_status_code
)
OVERRIDING SYSTEM VALUE
VALUES (
    1000,
    'admin@talentra.io',
    CURRENT_TIMESTAMP,
    'System Administrator',
    'active'
)
ON CONFLICT (email) DO NOTHING;

INSERT INTO administration.user_credential (
    user_account_id, credential_type_code, password_hash, is_active
)
SELECT 1000, 'password', '$argon2id$v=19$m=65536,t=3,p=4$YWRtaW5zYWx0$YWRtaW5oYXNoZml4dHVyZWFkbWluMTIzNDU2', true
WHERE NOT EXISTS (
    SELECT 1 FROM administration.user_credential 
    WHERE user_account_id = 1000 AND credential_type_code = 'password'
);

INSERT INTO administration.user_role (user_account_id, role_id)
SELECT 1000, r.id
FROM administration.role r WHERE r.code = 'super_admin'
ON CONFLICT DO NOTHING;

-- ----------------------------------------------------------------------------
-- 6. SEED RECRUITER ACCOUNT (Sarah Jenkins, id = 1002)
-- ----------------------------------------------------------------------------
INSERT INTO administration.user_account (
    id, email, email_verified_at, phone_e164, phone_country_code,
    display_name, account_status_code
)
OVERRIDING SYSTEM VALUE
VALUES (
    1002,
    'recruiter@techcorpglobal.com',
    CURRENT_TIMESTAMP,
    '+14155552671',
    '+1',
    'Sarah Jenkins',
    'active'
)
ON CONFLICT (email) DO NOTHING;

INSERT INTO administration.user_credential (
    user_account_id, credential_type_code, password_hash, is_active
)
SELECT 1002, 'password', '$argon2id$v=19$m=65536,t=3,p=4$cmVjcnVpdGVyc2FsdA$cmVjcnVpdGVyaGFzaGZpeHR1cmU0NTY3ODkw', true
WHERE NOT EXISTS (
    SELECT 1 FROM administration.user_credential 
    WHERE user_account_id = 1002 AND credential_type_code = 'password'
);

INSERT INTO administration.user_role (user_account_id, role_id)
SELECT 1002, r.id
FROM administration.role r WHERE r.code = 'recruiter'
ON CONFLICT DO NOTHING;

-- ----------------------------------------------------------------------------
-- 7. SEED INITIAL PRIVACY CONSENT EVIDENCE
-- ----------------------------------------------------------------------------
INSERT INTO administration.consent_record (
    user_account_id, purpose_code, notice_version, decision_code, collection_source_code
)
VALUES 
    (1001, 'recruitment_matching', 'v2026.1', 'granted', 'web'),
    (1001, 'profile_discovery', 'v2026.1', 'granted', 'web');

-- ----------------------------------------------------------------------------
-- 8. ATTACH PHASE 1 CROSS-MODULE BRIDGE FOREIGN KEY
-- Now that user 1001 is guaranteed to exist, attach the foreign key constraint.
-- ----------------------------------------------------------------------------
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint 
        WHERE conname = 'fk_candidate_profile_user_id'
    ) THEN
        ALTER TABLE profile.candidate_profile
            ADD CONSTRAINT fk_candidate_profile_user_id
            FOREIGN KEY (user_id) REFERENCES administration.user_account(id)
            ON UPDATE RESTRICT ON DELETE SET NULL;
    END IF;
END;
$$;

COMMIT;
