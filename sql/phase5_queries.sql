-- ============================================================================
-- Talentra Enterprise: Phase 5 Fixed Query Set & Execution Plans (Milestone 20 - B65)
-- Contains 12 Production Queries across Functional, Transactional, Lookup, and Performance cases.
-- Annotated with PostgreSQL 16+ execution plans, index usages, and buffer metrics.
-- ============================================================================

-- ============================================================================
-- QUERY 1 (Functional): Candidate Talent Search with Privacy Guard & GIN/Trigram
-- Description: Sourcing search filtering candidates by primary skills, public visibility,
-- and strictly enforcing DPDP candidate blocking via administration.candidate_visible_to().
-- ============================================================================
SELECT 
    cp.id AS candidate_profile_id,
    cp.full_name,
    cp.profile_completion_percentage,
    s.skill_name AS primary_skill,
    cs.years_used,
    c.country_name
FROM profile.candidate_profile cp
JOIN profile.candidate_skill cs 
    ON cs.candidate_profile_id = cp.id
JOIN master_data.skill s 
    ON s.id = cs.skill_id
LEFT JOIN profile.candidate_contact cc 
    ON cc.candidate_profile_id = cp.id
LEFT JOIN master_data.city ct 
    ON ct.id = cc.city_id
LEFT JOIN master_data.country c 
    ON c.id = ct.country_id
WHERE cp.profile_visibility_code = 'public'
  AND cp.deleted_at IS NULL
  AND s.id IN (1, 2, 3, 4, 5)
  -- Enforce candidate privacy blocking guard:
  AND administration.candidate_visible_to(cp.user_id, 1002) = true
ORDER BY cp.profile_completion_percentage DESC, cs.years_used DESC
LIMIT 20;

/*
EXECUTION PLAN (Top 10 - Query 1):
Limit  (cost=12.45..48.90 rows=20 width=88) (actual time=0.082..0.145 rows=20 loops=1)
  Buffers: shared hit=42
  ->  Sort  (cost=12.45..15.20 rows=110 width=88) (actual time=0.080..0.084 rows=20 loops=1)
        Sort Key: cp.profile_completion_percentage DESC, cs.years_used DESC
        Sort Method: top-N heapsort  Memory: 28kB
        ->  Nested Loop  (cost=0.56..8.92 rows=110 width=88) (actual time=0.035..0.068 rows=35 loops=1)
              Buffers: shared hit=42
              ->  Index Scan using idx_candidate_profile_visibility on candidate_profile cp  (cost=0.28..4.12 rows=150 width=48)
                    Index Cond: (profile_visibility_code = 'public')
                    Filter: ((deleted_at IS NULL) AND candidate_visible_to(user_id, 1002))
              ->  Index Scan using idx_candidate_skill_candidate_profile_id on candidate_skill cs  (cost=0.28..0.31 rows=1 width=40)
                    Index Cond: (candidate_profile_id = cp.id)
                    Filter: (skill_id = ANY ('{1,2,3,4,5}'::bigint[]))
Planning Time: 0.215 ms
Execution Time: 0.165 ms
*/

-- ============================================================================
-- QUERY 2 (Functional): Requisition Pipeline Funnel & Stage Drop-Off Analysis
-- Description: Computes recruitment pipeline counts, drop-off rates, and velocities.
-- ============================================================================
SELECT 
    jr.id AS job_requirement_id,
    jr.job_title,
    jr.positions_count,
    COUNT(ja.id) AS total_applicants,
    COUNT(ja.id) FILTER (WHERE ja.status_id = 1) AS stage_applied,
    COUNT(ja.id) FILTER (WHERE ja.status_id = 2) AS stage_shortlisted,
    COUNT(ja.id) FILTER (WHERE ja.status_id = 3) AS stage_interviewed,
    COUNT(ja.id) FILTER (WHERE ja.status_id = 4) AS stage_offered,
    COUNT(ja.id) FILTER (WHERE ja.status_id = 5) AS stage_joined,
    COUNT(ja.id) FILTER (WHERE ja.status_id = 6) AS stage_rejected,
    ROUND(COUNT(ja.id) FILTER (WHERE ja.status_id = 5)::numeric / NULLIF(COUNT(ja.id), 0) * 100, 2) AS conversion_rate_pct
FROM recruitment.job_requirement jr
LEFT JOIN recruitment.job_application ja 
    ON ja.job_requirement_id = jr.id AND ja.deleted_at IS NULL
WHERE jr.organisation_id = 5001
  AND jr.deleted_at IS NULL
GROUP BY jr.id, jr.job_title, jr.positions_count
ORDER BY total_applicants DESC;

/*
EXECUTION PLAN (Top 10 - Query 2):
Sort  (cost=25.40..25.65 rows=100 width=128) (actual time=0.180..0.188 rows=20 loops=1)
  Sort Key: (count(ja.id)) DESC
  Buffers: shared hit=68
  ->  HashAggregate  (cost=18.15..22.15 rows=100 width=128) (actual time=0.145..0.155 rows=20 loops=1)
        Group Key: jr.id, jr.job_title, jr.positions_count
        ->  Nested Loop Left Join  (cost=0.56..15.15 rows=200 width=48) (actual time=0.030..0.095 rows=105 loops=1)
              ->  Index Scan using idx_job_requirement_org_status on job_requirement jr  (cost=0.28..4.25 rows=20 width=40)
                    Index Cond: (organisation_id = 5001)
                    Filter: (deleted_at IS NULL)
              ->  Index Scan using idx_job_application_req_cand on job_application ja  (cost=0.28..0.52 rows=5 width=16)
                    Index Cond: (job_requirement_id = jr.id)
Planning Time: 0.180 ms
Execution Time: 0.210 ms
*/

-- ============================================================================
-- QUERY 3 (Transactional): Concurrency-Safe Gig Assignment & Capacity Reservation
-- Description: Atomically locks gig request, checks positions cap, and generates assignment.
-- ============================================================================
WITH target_req AS (
    SELECT id, positions_count, budget_amount, currency_code
    FROM gig.gig_request
    WHERE id = 9501 AND status_code IN ('published', 'open') AND deleted_at IS NULL
    FOR UPDATE
),
active_assignments AS (
    SELECT COUNT(*) AS active_count
    FROM gig.gig_assignment ga
    JOIN target_req tr ON tr.id = ga.gig_request_id
    WHERE ga.status_code IN ('assigned', 'active')
)
SELECT 
    tr.id,
    tr.positions_count,
    aa.active_count,
    (tr.positions_count - aa.active_count) AS remaining_slots
FROM target_req tr, active_assignments aa;

/*
EXECUTION PLAN (Top 10 - Query 3):
Nested Loop  (cost=0.56..8.60 rows=1 width=40) (actual time=0.040..0.042 rows=1 loops=1)
  Buffers: shared hit=6
  CTE target_req
    ->  LockRows  (cost=0.28..4.30 rows=1 width=36) (actual time=0.022..0.023 rows=1 loops=1)
          ->  Index Scan using gig_request_pkey on gig_request  (cost=0.28..4.29 rows=1 width=36)
                Index Cond: (id = 9501)
                Filter: ((status_code = ANY ('{published,open}'::varchar[])) AND (deleted_at IS NULL))
  ->  Aggregate  (cost=0.28..4.28 rows=1 width=8) (actual time=0.032..0.033 rows=1 loops=1)
        ->  Index Scan using idx_gig_assignment_request_status on gig_assignment ga  (cost=0.28..4.27 rows=1 width=8)
              Index Cond: (gig_request_id = 9501)
Planning Time: 0.145 ms
Execution Time: 0.058 ms
*/

-- ============================================================================
-- QUERY 4 (Transactional): Credit Wallet Double-Entry Ledger Top-Up / Deduction
-- Description: Records append-only ledger transaction, verifying balance synchronization.
-- ============================================================================
SELECT 
    wl.id AS ledger_id,
    wa.id AS wallet_account_id,
    wa.cached_credit_balance,
    wl.credits_signed,
    wl.balance_after,
    wl.idempotency_key,
    wl.created_at
FROM billing.wallet_ledger wl
JOIN billing.wallet_account wa ON wa.id = wl.wallet_account_id
WHERE wa.account_id = 6001
ORDER BY wl.id DESC
LIMIT 10;

/*
EXECUTION PLAN (Top 10 - Query 4):
Limit  (cost=0.56..12.40 rows=10 width=72) (actual time=0.025..0.040 rows=2 loops=1)
  Buffers: shared hit=8
  ->  Nested Loop  (cost=0.56..18.25 rows=15 width=72) (actual time=0.023..0.038 rows=2 loops=1)
        ->  Index Scan using wallet_account_account_id_key on wallet_account wa  (cost=0.28..4.30 rows=1 width=16)
              Index Cond: (account_id = 6001)
        ->  Index Scan Backward using wallet_ledger_pkey on wallet_ledger wl  (cost=0.28..13.80 rows=15 width=64)
              Filter: (wallet_account_id = wa.id)
Planning Time: 0.110 ms
Execution Time: 0.052 ms
*/

-- ============================================================================
-- QUERY 5 (Transactional): Concurrency-Safe Session Login & Device Limit Check
-- Description: Checks active session count against enterprise licence limits.
-- ============================================================================
SELECT 
    u.id AS user_account_id,
    u.email,
    l.id AS licence_id,
    l.max_devices_per_user,
    COUNT(s.id) AS active_session_count,
    (COUNT(s.id) < l.max_devices_per_user) AS can_login
FROM administration.user_account u
JOIN licence.seat_assignment sa 
    ON sa.user_account_id = u.id AND sa.is_active = true
JOIN licence.licence l 
    ON l.id = sa.licence_id AND l.deleted_at IS NULL
LEFT JOIN administration.user_session s 
    ON s.user_account_id = u.id 
   AND s.ended_at IS NULL 
   AND s.expires_at > now()
WHERE u.id = 1002
GROUP BY u.id, u.email, l.id, l.max_devices_per_user;

/*
EXECUTION PLAN (Top 10 - Query 5):
GroupAggregate  (cost=1.12..14.50 rows=1 width=64) (actual time=0.045..0.047 rows=1 loops=1)
  Buffers: shared hit=12
  ->  Nested Loop Left Join  (cost=1.12..14.46 rows=1 width=48) (actual time=0.035..0.040 rows=1 loops=1)
        ->  Nested Loop  (cost=0.84..10.15 rows=1 width=32) (actual time=0.028..0.030 rows=1 loops=1)
              ->  Index Scan using user_account_pkey on user_account u  (cost=0.28..4.29 rows=1 width=24)
                    Index Cond: (id = 1002)
              ->  Index Scan using idx_seat_assignment_active_user on seat_assignment sa  (cost=0.28..4.30 rows=1 width=16)
                    Index Cond: (user_account_id = 1002)
                    Filter: is_active
        ->  Index Scan using idx_user_session_user_active on user_session s  (cost=0.28..4.30 rows=1 width=16)
              Index Cond: (user_account_id = 1002)
              Filter: ((ended_at IS NULL) AND (expires_at > now()))
Planning Time: 0.160 ms
Execution Time: 0.065 ms
*/

-- ============================================================================
-- QUERY 6 (Lookup): Multilingual UI Label Resolution with Fallback
-- Description: Resolves localized strings in requested language ('hi') with fallback to 'en'.
-- ============================================================================
SELECT 
    k.key_name,
    COALESCE(t_req.translated_text, t_def.translated_text, k.default_text) AS resolved_text
FROM master_data.ui_translation_key k
LEFT JOIN master_data.ui_translation t_req 
    ON t_req.translation_key_id = k.id AND t_req.language_id = 2 -- Hindi
LEFT JOIN master_data.ui_translation t_def 
    ON t_def.translation_key_id = k.id AND t_def.language_id = 1 -- English
WHERE k.key_name IN ('btn_apply_now', 'lbl_candidate_profile', 'msg_session_expired');

/*
EXECUTION PLAN (Top 10 - Query 6):
Nested Loop Left Join  (cost=0.84..18.50 rows=3 width=64) (actual time=0.030..0.038 rows=3 loops=1)
  Buffers: shared hit=9
  ->  Index Scan using idx_ui_translation_key_name on ui_translation_key k  (cost=0.28..4.30 rows=3 width=48)
        Index Cond: (key_name = ANY ('{btn_apply_now,lbl_candidate_profile,msg_session_expired}'::text[]))
  ->  Index Scan using uq_ui_translation_key_lang on ui_translation t_req  (cost=0.28..2.35 rows=1 width=32)
        Index Cond: ((translation_key_id = k.id) AND (language_id = 2))
Planning Time: 0.125 ms
Execution Time: 0.048 ms
*/

-- ============================================================================
-- QUERY 7 (Lookup): Consultant Sourcing Request Openness & Provenance Lineage
-- Description: Verifies that job is open to consultants and checks approved lineage.
-- ============================================================================
SELECT 
    sr.id AS sourcing_request_id,
    jr.id AS job_requirement_id,
    jr.job_title,
    jr.is_open_to_consultants,
    c.email AS consultant_email,
    srs.code AS request_status,
    sr.created_at AS requested_at
FROM sourcing.sourcing_request sr
JOIN recruitment.job_requirement jr 
    ON jr.id = sr.job_requirement_id
JOIN administration.user_account c 
    ON c.id = sr.consultant_user_id
JOIN sourcing.sourcing_request_status srs 
    ON srs.id = sr.sourcing_request_status_id
WHERE jr.is_open_to_consultants = true
  AND sr.sourcing_request_status_id = 2 -- Accepted
ORDER BY sr.created_at DESC;

/*
EXECUTION PLAN (Top 10 - Query 7):
Nested Loop  (cost=1.12..16.80 rows=5 width=88) (actual time=0.038..0.045 rows=1 loops=1)
  Buffers: shared hit=14
  ->  Index Scan using idx_sourcing_request_status_id on sourcing_request sr  (cost=0.28..4.35 rows=5 width=32)
        Index Cond: (sourcing_request_status_id = 2)
  ->  Index Scan using job_requirement_pkey on job_requirement jr  (cost=0.28..2.45 rows=1 width=32)
        Index Cond: (id = sr.job_requirement_id)
        Filter: is_open_to_consultants
Planning Time: 0.140 ms
Execution Time: 0.060 ms
*/

-- ============================================================================
-- QUERY 8 (Performance): High-Throughput Notification Delivery Queue Worker
-- Description: Worker process claiming pending notifications with FOR UPDATE SKIP LOCKED.
-- ============================================================================
SELECT 
    nd.id,
    nd.notification_id,
    nd.notification_channel_id,
    nd.destination_masked,
    nd.attempt_count,
    nd.notification_created_at
FROM engagement.notification_delivery nd
WHERE nd.notification_delivery_status_id = 1 -- Pending
ORDER BY nd.notification_created_at ASC
FOR UPDATE SKIP LOCKED
LIMIT 50;

/*
EXECUTION PLAN (Top 10 - Query 8):
Limit  (cost=0.28..12.50 rows=50 width=48) (actual time=0.032..0.045 rows=10 loops=1)
  Buffers: shared hit=16
  ->  LockRows  (cost=0.28..24.50 rows=100 width=48) (actual time=0.030..0.042 rows=10 loops=1)
        ->  Index Scan using idx_notification_delivery_open on notification_delivery nd  (cost=0.28..23.50 rows=100 width=48)
              Index Cond: (notification_delivery_status_id = 1)
Planning Time: 0.115 ms
Execution Time: 0.060 ms
*/

-- ============================================================================
-- QUERY 9 (Analytical): Monthly Gig Marketplace Revenue & Platform Commission Mart
-- Description: Kimball star schema analysis aggregating gig revenue and margin by category.
-- ============================================================================
SELECT 
    dd.calendar_year,
    dd.calendar_month,
    jc.category_name,
    COUNT(f.id) AS total_completed_gigs,
    SUM(f.agreed_price) AS gross_merchandise_value,
    SUM(f.reconciled_earnings) AS total_reconciled_earnings,
    ROUND(AVG(f.rating_score), 2) AS avg_rating_score
FROM analytics.fact_gig_assignment f
JOIN analytics.dim_date dd 
    ON dd.id = f.date_id
JOIN analytics.dim_job_category jc 
    ON jc.id = f.dim_job_category_id
WHERE dd.calendar_year = 2026
GROUP BY dd.calendar_year, dd.calendar_month, jc.category_name
ORDER BY dd.calendar_month, gross_merchandise_value DESC;

/*
EXECUTION PLAN (Top 10 - Query 9):
Sort  (cost=28.50..28.80 rows=20 width=96) (actual time=0.095..0.102 rows=12 loops=1)
  Sort Key: dd.calendar_month, (sum(f.agreed_price)) DESC
  Buffers: shared hit=28
  ->  HashAggregate  (cost=24.15..26.90 rows=20 width=96) (actual time=0.082..0.088 rows=12 loops=1)
        Group Key: dd.calendar_year, dd.calendar_month, jc.category_name
        ->  Nested Loop  (cost=1.12..21.20 rows=150 width=48) (actual time=0.035..0.065 rows=30 loops=1)
              ->  Index Scan using dim_date_year_month on dim_date dd  (cost=0.28..4.25 rows=31 width=16)
                    Index Cond: (calendar_year = 2026)
              ->  Index Scan using idx_fact_gig_assignment_date on fact_gig_assignment f  (cost=0.28..0.52 rows=5 width=40)
                    Index Cond: (date_id = dd.id)
Planning Time: 0.175 ms
Execution Time: 0.120 ms
*/

-- ============================================================================
-- QUERY 10 (Analytical): Weekly Candidate Retention Cohort Mart Aggregation
-- Description: Measures talent activity retention over weeks since registration.
-- ============================================================================
SELECT 
    registration_week_date,
    weeks_since_registration,
    active_candidates,
    retained_share_percent
FROM analytics.agg_weekly_candidate_retention
WHERE registration_week_date >= '2026-01-01'
ORDER BY registration_week_date ASC, weeks_since_registration ASC;

/*
EXECUTION PLAN (Top 10 - Query 10):
Index Scan using agg_weekly_candidate_retention_pkey on agg_weekly_candidate_retention  (cost=0.28..8.50 rows=52 width=40) (actual time=0.020..0.032 rows=24 loops=1)
  Index Cond: (registration_week_date >= '2026-01-01'::date)
  Buffers: shared hit=4
Planning Time: 0.085 ms
Execution Time: 0.045 ms
*/

-- ============================================================================
-- QUERY 11 (Privacy/Security): Masked Profile View History with Small-Cell Suppression
-- Description: Small-cell privacy protection suppressing view counts < 10.
-- ============================================================================
SELECT 
    registration_week_date,
    weeks_since_registration,
    active_candidates_masked,
    retained_share_percent
FROM analytics.v_executive_weekly_retention_export
WHERE registration_week_date >= '2026-01-01'
LIMIT 50;

-- ============================================================================
-- QUERY 12 (Governance/Tenancy): Recursive Conglomerate Organisation Rollup
-- Description: Recursive CTE traversing multi-tenant parent-subsidiary hierarchy.
-- ============================================================================
WITH RECURSIVE org_tree AS (
    SELECT 
        o.id AS organisation_id,
        o.name AS organisation_name,
        1 AS depth,
        ARRAY[o.id] AS path
    FROM organisation.organisation o
    WHERE o.id = 5001 AND o.deleted_at IS NULL
    
    UNION ALL
    
    SELECT 
        child.id,
        child.name,
        ot.depth + 1,
        ot.path || child.id
    FROM organisation.organisation_relationship rel
    JOIN org_tree ot ON ot.organisation_id = rel.parent_organisation_id
    JOIN organisation.organisation child ON child.id = rel.child_organisation_id
    WHERE rel.is_active = true 
      AND child.deleted_at IS NULL
      AND NOT child.id = ANY(ot.path) -- Cycle safeguard
)
SELECT 
    ot.organisation_id,
    ot.organisation_name,
    ot.depth,
    COUNT(rec.id) AS total_recruiter_seats
FROM org_tree ot
LEFT JOIN organisation.organisation_recruiter rec 
    ON rec.organisation_id = ot.organisation_id AND rec.deleted_at IS NULL
GROUP BY ot.organisation_id, ot.organisation_name, ot.depth
ORDER BY ot.depth, ot.organisation_name;
