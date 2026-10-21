-- ============================================================================
-- Talentra Enterprise: Module-Specific Verification Queries (Milestone 20 - B67, B68, B69)
-- B67: Administration, Organisation, and Gig Marketplace (Member A)
-- B68: Licences, Sourcing, and Subscriptions / Wallet (Member B)
-- B69: Notifications, Analytics, and Shared Team Governance (Member C)
-- ============================================================================

-- ============================================================================
-- MEMBER A: ADMINISTRATION, ORGANISATION & GIG MARKETPLACE (B67)
-- ============================================================================

-- 1. Administration: Verify active user roles and RBAC permission aggregation
SELECT 
    u.id AS user_account_id,
    u.email,
    r.code AS role_code,
    r.name AS role_name,
    COUNT(rp.permission_id) AS granted_permissions_count
FROM administration.user_account u
JOIN administration.user_role ur ON ur.user_account_id = u.id AND ur.is_active = true
JOIN administration.role r ON r.id = ur.role_id
LEFT JOIN administration.role_permission rp ON rp.role_id = r.id
WHERE u.id IN (1001, 1002, 1003)
GROUP BY u.id, u.email, r.code, r.name;

-- 2. Organisation: Recruiter seat allocation & branch office locations
SELECT 
    o.id AS organisation_id,
    o.name AS company_name,
    ol.location_name,
    ol.is_headquarters,
    COUNT(rec.id) AS mapped_recruiters_count
FROM organisation.organisation o
JOIN organisation.organisation_location ol 
    ON ol.organisation_id = o.id AND ol.deleted_at IS NULL
LEFT JOIN organisation.organisation_recruiter rec 
    ON rec.organisation_id = o.id AND rec.deleted_at IS NULL
WHERE o.id = 5001
GROUP BY o.id, o.name, ol.location_name, ol.is_headquarters;

-- 3. Gig Marketplace: Worker profile, service catalog, and average rating
SELECT 
    gwp.id AS worker_profile_id,
    gwp.professional_summary,
    gwp.years_experience,
    gws.service_name,
    gws.minimum_rate,
    gws.maximum_rate,
    COUNT(ga.id) AS completed_assignments_count
FROM gig.gig_worker_profile gwp
LEFT JOIN gig.gig_worker_service gws ON gws.gig_worker_profile_id = gwp.id
LEFT JOIN gig.gig_assignment ga 
    ON ga.gig_worker_profile_id = gwp.id AND ga.status_code = 'completed'
WHERE gwp.id = 7001
GROUP BY gwp.id, gwp.professional_summary, gwp.years_experience, gws.service_name, gws.minimum_rate, gws.maximum_rate;

-- ============================================================================
-- MEMBER B: LICENCES, SOURCING & SUBSCRIPTIONS / WALLET (B68)
-- ============================================================================

-- 4. Licences & Devices: Current active seats vs max seats allowance
SELECT 
    l.id AS licence_id,
    l.max_users AS quota_max_users,
    l.max_devices_per_user,
    COUNT(sa.id) AS active_seat_count,
    (l.max_users - COUNT(sa.id)) AS available_seats
FROM licence.licence l
LEFT JOIN licence.seat_assignment sa 
    ON sa.licence_id = l.id AND sa.is_active = true
WHERE l.id = 101
GROUP BY l.id, l.max_users, l.max_devices_per_user;

-- 5. Sourcing & Outreach: Campaign batches and shortlisted talent conversion
SELECT 
    ob.id AS batch_id,
    ob.campaign_name,
    ob.total_recipients,
    COUNT(obr.id) AS sent_messages_count,
    COUNT(obr.id) FILTER (WHERE obr.response_received_at IS NOT NULL) AS responses_received,
    ROUND(COUNT(obr.id) FILTER (WHERE obr.response_received_at IS NOT NULL)::numeric / NULLIF(ob.total_recipients, 0) * 100, 2) AS response_rate_pct
FROM sourcing.outreach_batch ob
LEFT JOIN sourcing.outreach_recipient obr ON obr.outreach_batch_id = ob.id
WHERE ob.organisation_id = 5001
GROUP BY ob.id, ob.campaign_name, ob.total_recipients;

-- 6. Billing: Subscription contract period, status, and double-entry wallet balance
SELECT 
    s.id AS subscription_id,
    p.name AS plan_name,
    s.subscription_status_id,
    sp.valid_range,
    w.cached_credit_balance AS wallet_credit_balance
FROM billing.account_subscription s
JOIN billing.subscription_plan p ON p.id = s.subscription_plan_id
JOIN billing.wallet_account w ON w.account_id = s.account_id
LEFT JOIN billing.subscription_period sp ON sp.account_subscription_id = s.id
WHERE s.account_id = 6001;

-- ============================================================================
-- MEMBER C: NOTIFICATIONS, ANALYTICS & SHARED TEAM ITEMS (B69)
-- ============================================================================

-- 7. Notifications: Delivery success rate by communication channel
SELECT 
    nc.name AS channel_name,
    COUNT(nd.id) AS total_deliveries,
    COUNT(nd.id) FILTER (WHERE nd.notification_delivery_status_id = 3) AS successful_deliveries,
    COUNT(nd.id) FILTER (WHERE nd.notification_delivery_status_id = 4) AS failed_deliveries,
    ROUND(AVG(nd.attempt_count), 2) AS avg_attempts_per_delivery
FROM engagement.notification_channel nc
LEFT JOIN engagement.notification_delivery nd ON nd.notification_channel_id = nc.id
GROUP BY nc.name;

-- 8. Analytics Star Schema: ETL Load Watermarks and SCD2 dimension counts
SELECT 
    'dim_candidate' AS dimension_table,
    COUNT(*) AS total_versions,
    COUNT(*) FILTER (WHERE is_current = true) AS current_active_records
FROM analytics.dim_candidate
UNION ALL
SELECT 
    'dim_organisation',
    COUNT(*),
    COUNT(*) FILTER (WHERE is_current = true)
FROM analytics.dim_organisation
UNION ALL
SELECT 
    'dim_gig_worker',
    COUNT(*),
    COUNT(*) FILTER (WHERE is_current = true)
FROM analytics.dim_gig_worker;

-- 9. Shared Team Governance: Audit trail volume and DPDP active consent rate
SELECT 
    cp.title AS purpose_title,
    cp.active_notice_version,
    COUNT(cr.id) AS consents_granted_count,
    COUNT(cr.id) FILTER (WHERE cr.revoked_at IS NULL) AS active_valid_consents
FROM administration.consent_purpose cp
LEFT JOIN administration.consent_record cr ON cr.consent_purpose_id = cp.id
GROUP BY cp.title, cp.active_notice_version;
