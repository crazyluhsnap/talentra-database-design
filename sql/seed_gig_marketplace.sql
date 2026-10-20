-- ============================================================================
-- Talentra: Gig Marketplace Module Seed Data
-- Engine: PostgreSQL 14+
-- Populates service categories, marketplace lookups, transitions, and sample fixtures.
-- ============================================================================

BEGIN;

-- 1. Master Data Service Categories
INSERT INTO master_data.service_category (code, name, description, sort_order)
VALUES
    ('software_engineering', 'Software Engineering & Architecture', 'Full-stack development, backend systems, APIs', 1),
    ('ui_ux_design', 'UI/UX & Product Design', 'User research, wireframing, Figma design systems', 2),
    ('cloud_devops', 'Cloud Infrastructure & DevOps', 'Kubernetes, AWS/GCP architecture, CI/CD automation', 3),
    ('data_science_ai', 'Data Science & Machine Learning', 'Data pipelines, LLM fine-tuning, analytics', 4),
    ('technical_writing', 'Technical Writing & Documentation', 'API docs, developer guides, whitepapers', 5),
    ('qa_automation', 'QA Automation & Security Auditing', 'Automated test suites, penetration testing', 6)
ON CONFLICT (code) DO NOTHING;

-- 2. Availability Statuses
INSERT INTO gig.lk_gig_availability_status (code, description)
VALUES
    ('accepting_work', 'Worker actively accepting new gig assignments'),
    ('unavailable', 'Worker temporarily unavailable for new work'),
    ('paused', 'Worker profile visibility temporarily paused')
ON CONFLICT (code) DO NOTHING;

-- 3. Visibility Statuses
INSERT INTO gig.lk_gig_visibility_status (code, description)
VALUES
    ('public', 'Profile visible in public gig marketplace search'),
    ('private', 'Profile visible only via direct link or invite'),
    ('unlisted', 'Hidden from all directory listings')
ON CONFLICT (code) DO NOTHING;

-- 4. Work Modes
INSERT INTO gig.lk_gig_work_mode (code, description)
VALUES
    ('remote', '100% remote asynchronous or synchronous delivery'),
    ('onsite', 'Physical presence required at specified city/office'),
    ('hybrid', 'Combined remote and physical presence')
ON CONFLICT (code) DO NOTHING;

-- 5. Pricing Types
INSERT INTO gig.lk_gig_pricing_type (code, description)
VALUES
    ('fixed_price', 'Single milestone or project-based fixed deliverable price'),
    ('rate_based', 'Hourly, daily, or monthly time-and-materials rate')
ON CONFLICT (code) DO NOTHING;

-- 6. Rate Units
INSERT INTO gig.lk_gig_rate_unit (code, description)
VALUES
    ('hour', 'Per hour billable unit'),
    ('day', 'Per day (8-hour standard) unit'),
    ('project', 'Lump sum project deliverable unit'),
    ('month', 'Monthly retainer unit')
ON CONFLICT (code) DO NOTHING;

-- 7. Request Statuses
INSERT INTO gig.lk_gig_request_status (code, description)
VALUES
    ('draft', 'Draft gig requisition not yet visible on marketplace'),
    ('published', 'Active gig requisition accepting proposals'),
    ('paused', 'Requisition temporarily not accepting new proposals'),
    ('closed', 'Requisition fulfilled and closed to proposals'),
    ('cancelled', 'Requisition cancelled by requester')
ON CONFLICT (code) DO NOTHING;

-- 8. Application Statuses
INSERT INTO gig.lk_gig_application_status (code, description)
VALUES
    ('pending', 'Proposal submitted and awaiting requester review'),
    ('accepted', 'Proposal accepted, assignment contract created'),
    ('rejected', 'Proposal reviewed and declined by requester'),
    ('withdrawn', 'Proposal withdrawn by gig worker')
ON CONFLICT (code) DO NOTHING;

-- 9. Assignment Statuses
INSERT INTO gig.lk_gig_assignment_status (code, description)
VALUES
    ('pending_handoff', 'Contract executed, awaiting external repository/tool handoff'),
    ('active', 'Gig delivery currently underway'),
    ('completed', 'All deliverables completed and approved'),
    ('terminated', 'Assignment prematurely terminated by mutual agreement or breach'),
    ('disputed', 'Escalated to dispute resolution')
ON CONFLICT (code) DO NOTHING;

-- 10. Proficiency Levels
INSERT INTO gig.lk_gig_proficiency_level (code, description)
VALUES
    ('beginner', 'Entry-level proficiency (1-2 years experience)'),
    ('intermediate', 'Competent practitioner (3-5 years experience)'),
    ('expert', 'Senior master / specialist (6+ years experience)')
ON CONFLICT (code) DO NOTHING;

-- 11. State Machine Transitions (Valid legal transitions per section 7)
INSERT INTO gig.gig_status_transition (entity_type, from_status_code, to_status_code)
VALUES
    -- Request transitions
    ('request', 'draft', 'published'),
    ('request', 'published', 'paused'),
    ('request', 'paused', 'published'),
    ('request', 'published', 'closed'),
    ('request', 'published', 'cancelled'),
    ('request', 'draft', 'cancelled'),
    -- Application transitions
    ('application', 'pending', 'accepted'),
    ('application', 'pending', 'rejected'),
    ('application', 'pending', 'withdrawn'),
    -- Assignment transitions
    ('assignment', 'pending_handoff', 'active'),
    ('assignment', 'active', 'completed'),
    ('assignment', 'active', 'disputed'),
    ('assignment', 'active', 'terminated'),
    ('assignment', 'disputed', 'completed'),
    ('assignment', 'disputed', 'terminated')
ON CONFLICT DO NOTHING;

-- 12. Seed Sample Gig Worker Profile for Aarav Sharma (user 1001, candidate 1)
INSERT INTO gig.gig_worker_profile (
    id, app_user_id, candidate_profile_id, professional_summary, portfolio_url,
    availability_status_code, visibility_status_code, years_experience,
    created_by, updated_by
)
OVERRIDING SYSTEM VALUE
VALUES (
    7001,
    1001,
    (SELECT id FROM profile.candidate_profile LIMIT 1),
    'Specialist Senior PostgreSQL Database Architect & Go/Rust Backend Engineer with 8+ years building high-throughput systems.',
    'https://aaravsharma.dev/portfolio',
    'accepting_work',
    'public',
    8.5,
    1001,
    1001
)
ON CONFLICT (id) DO NOTHING;

-- Seed Service Offering
INSERT INTO gig.gig_worker_service (
    gig_worker_profile_id, service_category_id, service_name, description,
    minimum_rate, maximum_rate, rate_unit_code, currency_code,
    created_by, updated_by
)
SELECT 
    7001,
    (SELECT id FROM master_data.service_category WHERE code = 'software_engineering'),
    'PostgreSQL Schema Design & Query Optimization',
    'High-concurrency database modeling, B-tree/GIN index tuning, and EXCLUDE constraint design.',
    75.00,
    120.00,
    'hour',
    'USD',
    1001,
    1001
WHERE NOT EXISTS (
    SELECT 1 FROM gig.gig_worker_service 
    WHERE gig_worker_profile_id = 7001 AND service_name = 'PostgreSQL Schema Design & Query Optimization'
);

-- 13. Seed Sample Published Gig Request (Sponsored by TechCorp Global 5001, Requester Sarah Jenkins 1002)
INSERT INTO gig.gig_request (
    id, requester_user_id, organisation_id, service_category_id, title, description,
    work_mode_code, start_at, end_at, positions_count, pricing_type_code,
    budget_amount, currency_code, status_code, published_at,
    created_by, updated_by
)
OVERRIDING SYSTEM VALUE
VALUES (
    8001,
    1002, -- Sarah Jenkins (Recruiter / Hiring Authority)
    5001, -- TechCorp Global
    (SELECT id FROM master_data.service_category WHERE code = 'software_engineering'),
    'PostgreSQL High-Concurrency Database Architecture Review',
    'Perform deep DDL audit and write EXCLUDE constraint rules for our upcoming microservice architecture.',
    'remote',
    CURRENT_TIMESTAMP + INTERVAL '1 day',
    CURRENT_TIMESTAMP + INTERVAL '30 days',
    1,
    'fixed_price',
    3500.00,
    'USD',
    'published',
    CURRENT_TIMESTAMP,
    1002,
    1002
)
ON CONFLICT (id) DO NOTHING;

-- 14. Seed End-to-End Golden Narrative: Application -> Assignment -> Fulfilment -> Earnings -> Rating
-- Aarav Sharma (Worker Profile 7001) applies for TechCorp Request 8001
INSERT INTO gig.gig_application (
    id, gig_request_id, gig_worker_profile_id, proposed_amount, currency_code,
    proposal_text, status_code, applied_at, decided_by_user_id, decided_at, decision_note,
    created_by, updated_by
)
OVERRIDING SYSTEM VALUE
VALUES (
    8501,
    8001,
    7001,
    3500.00,
    'USD',
    'I have 8+ years designing zero-regression schemas and EXCLUDE constraints in PostgreSQL 14+. I can deliver full DDL audit within 14 days.',
    'accepted',
    CURRENT_TIMESTAMP - INTERVAL '5 days',
    1002, -- Sarah Jenkins accepted
    CURRENT_TIMESTAMP - INTERVAL '4 days',
    'Impressive track record and precise proposal. Approved for immediate execution.',
    1001,
    1002
)
ON CONFLICT (id) DO NOTHING;

-- Executed Contract Assignment (id = 9001)
INSERT INTO gig.gig_assignment (
    id, gig_request_id, gig_application_id, gig_worker_profile_id,
    pricing_type_code, agreed_amount, currency_code, status_code,
    assigned_at, started_at, completed_at, created_by, updated_by
)
OVERRIDING SYSTEM VALUE
VALUES (
    9001,
    8001,
    8501,
    7001,
    'fixed_price',
    3500.00,
    'USD',
    'completed',
    CURRENT_TIMESTAMP - INTERVAL '4 days',
    CURRENT_TIMESTAMP - INTERVAL '4 days',
    CURRENT_TIMESTAMP - INTERVAL '1 day',
    1002,
    1002
)
ON CONFLICT (id) DO NOTHING;

-- External Delivery Repository Fulfilment Link
INSERT INTO gig.gig_fulfilment_reference (
    id, gig_assignment_id, external_system_code, external_reference, sync_status_code,
    created_by, updated_by
)
OVERRIDING SYSTEM VALUE
VALUES (
    9101,
    9001,
    'github_repository',
    'https://github.com/techcorpglobal/database-architecture-review',
    'synced',
    1001,
    1001
)
ON CONFLICT (id) DO NOTHING;

-- Worker Earnings Escrow Payout Record
INSERT INTO gig.gig_earnings_reference (
    id, gig_assignment_id, latest_amount, currency_code, created_by, updated_by
)
OVERRIDING SYSTEM VALUE
VALUES (
    9201,
    9001,
    3500.00,
    'USD',
    1000,
    1000
)
ON CONFLICT (id) DO NOTHING;

INSERT INTO gig.gig_earnings_history (
    id, gig_earnings_reference_id, amount, change_type_code, reason, created_by
)
OVERRIDING SYSTEM VALUE
VALUES (
    9301,
    9201,
    3500.00,
    'milestone_payout',
    'Deliverable approved by TechCorp Global hiring team. 100% fixed-price escrow disbursed.',
    1000
)
ON CONFLICT (id) DO NOTHING;

-- 5-Star Feedback from Sarah Jenkins (1002) to Aarav Sharma (1001)
INSERT INTO gig.gig_rating (
    id, gig_assignment_id, rater_user_id, rated_user_id, rating_score, feedback_text, created_by
)
OVERRIDING SYSTEM VALUE
VALUES (
    9401,
    9001,
    1002, -- Sarah Jenkins
    1001, -- Aarav Sharma
    5,
    'Aarav delivered exceptional PostgreSQL schema designs, perfect recursive CTE hierarchy triggers, and zero-defect EXCLUDE constraints. Exactly the standard we needed!',
    1002
)
ON CONFLICT (id) DO NOTHING;

COMMIT;

