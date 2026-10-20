-- ============================================================================
-- Talentra: Organisation and Account Module Seed Data
-- Engine: PostgreSQL 14+
-- Populates 11 Lookup tables, status transitions, and reference organisations.
-- ============================================================================

BEGIN;

-- 1. Organisation Status
INSERT INTO organisation.organisation_status (code, sort_order)
VALUES
    ('pending_verification', 1),
    ('active', 2),
    ('suspended', 3),
    ('closed', 4)
ON CONFLICT (code) DO NOTHING;

-- 2. Organisation Type
INSERT INTO organisation.organisation_type (code, sort_order)
VALUES
    ('employer', 1),
    ('client', 2),
    ('staffing_agency', 3),
    ('consulting_agency', 4),
    ('campus_institution', 5),
    ('other', 6)
ON CONFLICT (code) DO NOTHING;

-- 3. Company Size Band
INSERT INTO organisation.company_size_band (code, sort_order)
VALUES
    ('size_1_10', 1),
    ('size_11_50', 2),
    ('size_51_200', 3),
    ('size_201_500', 4),
    ('size_501_1000', 5),
    ('size_1001_5000', 6),
    ('size_5001_plus', 7)
ON CONFLICT (code) DO NOTHING;

-- 4. Account Type
INSERT INTO organisation.account_type (code, sort_order)
VALUES
    ('employer', 1),
    ('agency', 2),
    ('consultant', 3),
    ('campus', 4)
ON CONFLICT (code) DO NOTHING;

-- 5. Account Status
INSERT INTO organisation.account_status (code, sort_order)
VALUES
    ('pending', 1),
    ('active', 2),
    ('suspended', 3),
    ('closed', 4)
ON CONFLICT (code) DO NOTHING;

-- 6. Verification Type
INSERT INTO organisation.verification_type (code, sort_order)
VALUES
    ('company_registration', 1),
    ('tax_identifier', 2),
    ('domain_ownership', 3)
ON CONFLICT (code) DO NOTHING;

-- 7. Verification Provider
INSERT INTO organisation.verification_provider (code, sort_order)
VALUES
    ('registry_api', 1),
    ('tax_api', 2),
    ('dns_check', 3),
    ('manual_review', 4)
ON CONFLICT (code) DO NOTHING;

-- 8. Verification Status
INSERT INTO organisation.verification_status (code, sort_order)
VALUES
    ('pending', 1),
    ('in_review', 2),
    ('retry_pending', 3),
    ('verified', 4),
    ('rejected', 5),
    ('expired', 6)
ON CONFLICT (code) DO NOTHING;

-- 9. Audit Action
INSERT INTO organisation.audit_action (code, sort_order)
VALUES
    ('row_insert', 1),
    ('row_update', 2),
    ('row_delete', 3),
    ('row_soft_delete', 4),
    ('administrator_granted', 5),
    ('administrator_revoked', 6),
    ('recruiter_assigned', 7),
    ('recruiter_unassigned', 8),
    ('recruiter_assignment_changed', 9),
    ('verification_status_changed', 10),
    ('verification_provider_called', 11),
    ('identifier_revealed', 12),
    ('access_denied', 13)
ON CONFLICT (code) DO NOTHING;

-- 10. Identifier Type (with standard validation patterns per PDF page 9)
INSERT INTO organisation.identifier_type (code, validation_pattern, sort_order)
VALUES
    ('gstin', '^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z][1-9A-Z]Z[0-9A-Z]$', 1),
    ('pan', '^[A-Z]{5}[0-9]{4}[A-Z]$', 2),
    ('cin', '^[LU][0-9]{5}[A-Z]{2}[0-9]{4}[A-Z]{3}[0-9]{6}$', 3),
    ('ein', '^[0-9]{2}-?[0-9]{7}$', 4),
    ('crn', '^([0-9]{8}|[A-Z]{2}[0-9]{6})$', 5),
    ('other', NULL, 6)
ON CONFLICT (code) DO NOTHING;

-- 11. Organisation Relationship Type
INSERT INTO organisation.organisation_relationship_type (code, is_hierarchical, sort_order)
VALUES
    ('parent_subsidiary', true, 1),
    ('franchise', false, 2),
    ('affiliate', false, 3),
    ('joint_venture', false, 4)
ON CONFLICT (code) DO NOTHING;

-- 12. Verification Status Transitions (Legal State Machine per Section 5.13)
INSERT INTO organisation.verification_status_transition (from_verification_status_id, to_verification_status_id)
SELECT f.id, t.id
FROM (VALUES
    ('pending', 'in_review'),
    ('in_review', 'verified'),
    ('in_review', 'rejected'),
    ('in_review', 'retry_pending'),
    ('retry_pending', 'in_review'),
    ('verified', 'expired'),
    ('rejected', 'pending'),
    ('expired', 'pending')
) AS pairs(from_code, to_code)
JOIN organisation.verification_status f ON f.code = pairs.from_code
JOIN organisation.verification_status t ON t.code = pairs.to_code
ON CONFLICT DO NOTHING;

-- 13. Seed Primary Corporate Organisation (TechCorp Global, id = 5001)
INSERT INTO organisation.organisation (
    id, organisation_name, legal_name, organisation_type_id, industry_id,
    company_size_band_id, founded_year, website_url, contact_email,
    contact_phone_e164, contact_phone_country_id, organisation_status_id,
    created_by, updated_by
)
OVERRIDING SYSTEM VALUE
VALUES (
    5001,
    'TechCorp Global',
    'TechCorp Global Technologies Private Limited',
    (SELECT id FROM organisation.organisation_type WHERE code = 'employer'),
    1, -- Master Data Technology Industry
    (SELECT id FROM organisation.company_size_band WHERE code = 'size_1001_5000'),
    2012,
    'https://www.techcorpglobal.com',
    'contact@techcorpglobal.com',
    '+14155552671',
    1, -- US country
    (SELECT id FROM organisation.organisation_status WHERE code = 'active'),
    1000, -- System Super Admin
    1000
)
ON CONFLICT (id) DO NOTHING;

-- Seed Corporate Platform Account (id = 6001)
INSERT INTO organisation.account (
    id, organisation_id, account_name, account_type_id, account_status_id,
    created_by, updated_by
)
OVERRIDING SYSTEM VALUE
VALUES (
    6001,
    5001,
    'TechCorp Global Enterprise Primary',
    (SELECT id FROM organisation.account_type WHERE code = 'employer'),
    (SELECT id FROM organisation.account_status WHERE code = 'active'),
    1000,
    1000
)
ON CONFLICT (id) DO NOTHING;

-- Map Recruiter Sarah Jenkins (id = 1002) to TechCorp Global
INSERT INTO organisation.organisation_recruiter (
    organisation_id, app_user_id, assignment_start_at, created_by, updated_by
)
SELECT 5001, 1002, CURRENT_TIMESTAMP, 1000, 1000
WHERE NOT EXISTS (
    SELECT 1 FROM organisation.organisation_recruiter 
    WHERE organisation_id = 5001 AND app_user_id = 1002
);

COMMIT;
