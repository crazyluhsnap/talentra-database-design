-- ============================================================================
-- Talentra Enterprise: Phase 4 Module C (Governance & Privacy) Seed Data
-- ============================================================================

\set ON_ERROR_STOP on

BEGIN;

DO $$
DECLARE
    v_admin_id bigint;
    v_type_recruitment_id bigint;
    v_type_comms_id bigint;
    v_del_action_id bigint;
    v_anon_action_id bigint;
BEGIN
    SELECT id INTO v_admin_id FROM administration.user_account ORDER BY id LIMIT 1;

    IF v_admin_id IS NOT NULL THEN
        -- 1. Credential Types
        INSERT INTO administration.credential_type (code, label_key, is_active, sort_order, created_by, updated_by)
        VALUES 
            ('password', 'admin.cred.password', true, 1, v_admin_id, v_admin_id),
            ('oidc_federated', 'admin.cred.oidc', true, 2, v_admin_id, v_admin_id),
            ('saml_enterprise', 'admin.cred.saml', true, 3, v_admin_id, v_admin_id),
            ('webauthn_passkey', 'admin.cred.passkey', true, 4, v_admin_id, v_admin_id)
        ON CONFLICT (code) DO NOTHING;

        -- 2. Consent Types & Statuses
        INSERT INTO administration.consent_type (code, label_key, is_active, sort_order, created_by, updated_by)
        VALUES 
            ('terms_of_service', 'admin.consent.tos', true, 1, v_admin_id, v_admin_id),
            ('privacy_policy_dpdp', 'admin.consent.dpdp', true, 2, v_admin_id, v_admin_id),
            ('marketing_comms', 'admin.consent.marketing', true, 3, v_admin_id, v_admin_id),
            ('profile_sharing', 'admin.consent.sharing', true, 4, v_admin_id, v_admin_id)
        ON CONFLICT (code) DO NOTHING;

        INSERT INTO administration.consent_status (code, label_key, is_active, sort_order, created_by, updated_by)
        VALUES 
            ('granted', 'admin.consent_status.granted', true, 1, v_admin_id, v_admin_id),
            ('withdrawn', 'admin.consent_status.withdrawn', true, 2, v_admin_id, v_admin_id),
            ('refused', 'admin.consent_status.refused', true, 3, v_admin_id, v_admin_id)
        ON CONFLICT (code) DO NOTHING;

        -- 3. Session End Reasons
        INSERT INTO administration.session_end_reason (code, label_key, is_active, sort_order, created_by, updated_by)
        VALUES 
            ('logout', 'admin.session_end.logout', true, 1, v_admin_id, v_admin_id),
            ('expired', 'admin.session_end.expired', true, 2, v_admin_id, v_admin_id),
            ('revoked_admin', 'admin.session_end.revoked', true, 3, v_admin_id, v_admin_id),
            ('limit_replaced', 'admin.session_end.replaced', true, 4, v_admin_id, v_admin_id)
        ON CONFLICT (code) DO NOTHING;

        -- 4. Login Outcomes & Reasons
        INSERT INTO administration.login_outcome (code, label_key, is_active, sort_order, created_by, updated_by)
        VALUES 
            ('success', 'admin.login.success', true, 1, v_admin_id, v_admin_id),
            ('failure', 'admin.login.failure', true, 2, v_admin_id, v_admin_id),
            ('locked', 'admin.login.locked', true, 3, v_admin_id, v_admin_id)
        ON CONFLICT (code) DO NOTHING;

        INSERT INTO administration.login_failure_reason (code, label_key, is_active, sort_order, created_by, updated_by)
        VALUES 
            ('bad_password', 'admin.login_fail.bad_pwd', true, 1, v_admin_id, v_admin_id),
            ('user_not_found', 'admin.login_fail.no_user', true, 2, v_admin_id, v_admin_id),
            ('mfa_failed', 'admin.login_fail.mfa', true, 3, v_admin_id, v_admin_id),
            ('ip_blocked', 'admin.login_fail.ip', true, 4, v_admin_id, v_admin_id)
        ON CONFLICT (code) DO NOTHING;

        -- 5. Audit Actions & Outcomes
        INSERT INTO administration.audit_action (code, label_key, is_active, sort_order, created_by, updated_by)
        VALUES 
            ('login', 'admin.audit.login', true, 1, v_admin_id, v_admin_id),
            ('session_limit_exceeded', 'admin.audit.session_limit', true, 2, v_admin_id, v_admin_id),
            ('profile_download', 'admin.audit.download', true, 3, v_admin_id, v_admin_id),
            ('user_block_created', 'admin.audit.block', true, 4, v_admin_id, v_admin_id)
        ON CONFLICT (code) DO NOTHING;

        INSERT INTO administration.audit_outcome (code, label_key, is_active, sort_order, created_by, updated_by)
        VALUES 
            ('granted', 'admin.audit_out.granted', true, 1, v_admin_id, v_admin_id),
            ('denied', 'admin.audit_out.denied', true, 2, v_admin_id, v_admin_id),
            ('error', 'admin.audit_out.error', true, 3, v_admin_id, v_admin_id)
        ON CONFLICT (code) DO NOTHING;

        -- 6. Block Reasons & Verification Outcomes
        INSERT INTO administration.block_reason (code, label_key, is_active, sort_order, created_by, updated_by)
        VALUES 
            ('unsolicited_outreach', 'admin.block_reason.outreach', true, 1, v_admin_id, v_admin_id),
            ('harassment', 'admin.block_reason.harassment', true, 2, v_admin_id, v_admin_id),
            ('previous_employer', 'admin.block_reason.prev_emp', true, 3, v_admin_id, v_admin_id),
            ('competitor_firm', 'admin.block_reason.competitor', true, 4, v_admin_id, v_admin_id)
        ON CONFLICT (code) DO NOTHING;

        INSERT INTO administration.identity_verification_outcome (code, label_key, is_active, sort_order, created_by, updated_by)
        VALUES 
            ('verified', 'admin.id_ver.verified', true, 1, v_admin_id, v_admin_id),
            ('pending', 'admin.id_ver.pending', true, 2, v_admin_id, v_admin_id),
            ('failed_match', 'admin.id_ver.failed', true, 3, v_admin_id, v_admin_id)
        ON CONFLICT (code) DO NOTHING;

        -- 7. Integration Boundaries & Exchange Statuses
        INSERT INTO administration.integration_boundary (code, label_key, is_active, sort_order, created_by, updated_by)
        VALUES 
            ('notification_gateway', 'admin.boundary.notify', true, 1, v_admin_id, v_admin_id),
            ('payment_gateway', 'admin.boundary.payment', true, 2, v_admin_id, v_admin_id),
            ('kyc_verification_service', 'admin.boundary.kyc', true, 3, v_admin_id, v_admin_id)
        ON CONFLICT (code) DO NOTHING;

        INSERT INTO administration.exchange_status (code, label_key, is_active, sort_order, created_by, updated_by)
        VALUES 
            ('received', 'admin.exchange.received', true, 1, v_admin_id, v_admin_id),
            ('acknowledged', 'admin.exchange.ack', true, 2, v_admin_id, v_admin_id),
            ('dispatched', 'admin.exchange.dispatched', true, 3, v_admin_id, v_admin_id),
            ('failed', 'admin.exchange.failed', true, 4, v_admin_id, v_admin_id)
        ON CONFLICT (code) DO NOTHING;

        -- 8. Data Request Types & Statuses
        INSERT INTO administration.data_request_type (code, label_key, is_active, sort_order, created_by, updated_by)
        VALUES 
            ('erasure_right_to_be_forgotten', 'admin.dpr.erasure', true, 1, v_admin_id, v_admin_id),
            ('export_portability', 'admin.dpr.export', true, 2, v_admin_id, v_admin_id),
            ('rectification', 'admin.dpr.rectify', true, 3, v_admin_id, v_admin_id)
        ON CONFLICT (code) DO NOTHING;

        INSERT INTO administration.data_request_status (code, label_key, is_active, sort_order, created_by, updated_by)
        VALUES 
            ('received', 'admin.dpr_status.received', true, 1, v_admin_id, v_admin_id),
            ('in_progress', 'admin.dpr_status.in_progress', true, 2, v_admin_id, v_admin_id),
            ('completed', 'admin.dpr_status.completed', true, 3, v_admin_id, v_admin_id),
            ('rejected', 'admin.dpr_status.rejected', true, 4, v_admin_id, v_admin_id)
        ON CONFLICT (code) DO NOTHING;

        -- 9. Error Severities & Retention Actions
        INSERT INTO administration.error_severity (code, label_key, is_active, sort_order, created_by, updated_by)
        VALUES 
            ('info', 'admin.err.info', true, 1, v_admin_id, v_admin_id),
            ('warning', 'admin.err.warn', true, 2, v_admin_id, v_admin_id),
            ('error', 'admin.err.error', true, 3, v_admin_id, v_admin_id),
            ('critical', 'admin.err.critical', true, 4, v_admin_id, v_admin_id)
        ON CONFLICT (code) DO NOTHING;

        INSERT INTO administration.retention_action (code, label_key, is_active, sort_order, created_by, updated_by)
        VALUES 
            ('delete', 'admin.ret_act.delete', true, 1, v_admin_id, v_admin_id),
            ('anonymise', 'admin.ret_act.anonymise', true, 2, v_admin_id, v_admin_id),
            ('archive', 'admin.ret_act.archive', true, 3, v_admin_id, v_admin_id)
        ON CONFLICT (code) DO NOTHING;

        -- 10. Sample Consent Policy (v1.0 DPDP Policy)
        SELECT id INTO v_type_recruitment_id FROM administration.consent_type WHERE code = 'privacy_policy_dpdp';
        IF v_type_recruitment_id IS NOT NULL THEN
            INSERT INTO administration.consent_policy (
                consent_type_id, version_label, effective_from, document_reference, created_by, updated_by
            )
            VALUES (
                v_type_recruitment_id, 'v1.0-2026', '2026-01-01', 'https://talentra.io/legal/dpdp-privacy-v1.0.pdf', v_admin_id, v_admin_id
            )
            ON CONFLICT (consent_type_id, version_label) DO NOTHING;
        END IF;

        -- 11. Sample Retention Policy Rules
        SELECT id INTO v_del_action_id FROM administration.retention_action WHERE code = 'delete';
        SELECT id INTO v_anon_action_id FROM administration.retention_action WHERE code = 'anonymise';

        IF v_del_action_id IS NOT NULL AND v_anon_action_id IS NOT NULL THEN
            INSERT INTO administration.retention_policy (entity_name, retention_interval, retention_action_id, legal_basis_text, created_by, updated_by)
            VALUES 
                ('engagement.notification_delivery', interval '90 days', v_del_action_id, 'Operational delivery tracking retention cap', v_admin_id, v_admin_id),
                ('administration.login_attempt', interval '180 days', v_del_action_id, 'Security authentication rate monitoring', v_admin_id, v_admin_id),
                ('profile.candidate_profile', interval '730 days', v_anon_action_id, 'Inactivity anonymisation under DPDP Act 2023', v_admin_id, v_admin_id)
            ON CONFLICT (entity_name) DO NOTHING;
        END IF;
    END IF;
END $$;

COMMIT;
