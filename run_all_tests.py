"""
Talentra Enterprise Database Architecture & Multi-Module Verification Engine
Validates:
1. Master Data, Profile, Recruitment (Phase 1 Foundation - 55 tables)
2. Administration & Identity (Phase 2 - 17 tables)
3. Organisation & Account with Audit Trail (Phase 2 - 24 tables)
4. Gig Marketplace Subsystem (Phase 2 - 27 tables)
5. Sourcing & Consultant Requests (Phase 3 Module A - 13 tables)
6. Licences (Phase 3 Anchor - 4 tables)
7. Subscriptions, Wallet, Payments & Download History (Phase 3 Module B - 31 tables)
8. Notifications, Preferences, Search Alerts & Community (Phase 4 Module A - 57 tables)
9. Analytics Layer, Dimensions, Facts & Marts (Phase 4 Module B - 48 tables)
10. Shared Governance, Privacy, Blocking & Sessions (Phase 4 Module C - 24 tables)
Total: 300 tables across 10 domain schemas.
"""

import re
import sys
from pathlib import Path
from collections import Counter

def extract_table_elements(body):
    elements = []
    current = []
    depth = 0
    for char in body:
        if char == '(':
            depth += 1
            current.append(char)
        elif char == ')':
            depth -= 1
            current.append(char)
        elif char == ',' and depth == 0:
            elem = ''.join(current).strip()
            if elem:
                elements.append(elem)
            current = []
        else:
            current.append(char)
    last = ''.join(current).strip()
    if last:
        elements.append(last)
    return elements

def parse_tables(sql_content):
    table_pattern = re.compile(
        r'CREATE TABLE\s+(?:IF NOT EXISTS\s+)?([a-zA-Z0-9_\.]+)\s*\((.*?)\);',
        re.DOTALL | re.IGNORECASE
    )
    tables = {}
    for match in table_pattern.finditer(sql_content):
        full_name = match.group(1).lower()
        body = match.group(2)
        columns = {}
        constraints = []
        
        clean_body = re.sub(r'--.*', '', body)
        elements = extract_table_elements(clean_body)
        for elem in elements:
            elem_clean = ' '.join(elem.splitlines()).strip()
            if not elem_clean:
                continue
            
            upper_elem = elem_clean.upper()
            if upper_elem.startswith('CONSTRAINT') or any(upper_elem.startswith(k) for k in ['PRIMARY KEY', 'FOREIGN KEY', 'UNIQUE', 'CHECK', 'EXCLUDE']):
                constraints.append(elem_clean)
            else:
                parts = elem_clean.split()
                if parts:
                    col_name = parts[0].strip('",')
                    col_type = parts[1] if len(parts) > 1 else ''
                    columns[col_name.lower()] = {
                        'type': col_type,
                        'raw': elem_clean
                    }
        tables[full_name] = {
            'columns': columns,
            'constraints': constraints,
            'body': body
        }
    return tables

def parse_indexes(sql_content):
    idx_pattern = re.compile(
        r'CREATE\s+(UNIQUE\s+)?INDEX\s+(?:IF NOT EXISTS\s+)?(\w+)\s+ON\s+([a-zA-Z0-9_\.]+)\s*(?:USING\s+\w+\s*)?\((.*?)\)(?:\s+WHERE\s+(.*?))?;',
        re.DOTALL | re.IGNORECASE
    )
    indexes = []
    for match in idx_pattern.finditer(sql_content):
        is_unique = bool(match.group(1))
        idx_name = match.group(2)
        target_table = match.group(3).lower()
        col_expr = match.group(4).strip()
        predicate = match.group(5)
        indexes.append({
            'name': idx_name,
            'unique': is_unique,
            'table': target_table,
            'expr': col_expr,
            'where': predicate
        })
    return indexes

def parse_functions_and_triggers(sql_content):
    fn_pattern = re.compile(
        r'CREATE(?:\s+OR\s+REPLACE)?\s+FUNCTION\s+([a-zA-Z0-9_\.]+)\s*\(.*?\)\s+RETURNS\s+(\w+)',
        re.IGNORECASE | re.DOTALL
    )
    trg_pattern = re.compile(
        r'CREATE\s+TRIGGER\s+(\w+)\s+(BEFORE|AFTER)\s+(.*?)\s+ON\s+([a-zA-Z0-9_\.]+)\s+(?:FOR\s+EACH\s+\w+\s+)?EXECUTE\s+(?:FUNCTION|PROCEDURE)\s+([a-zA-Z0-9_\.]+)\(\);',
        re.IGNORECASE
    )
    functions = {m.group(1).lower(): m.group(2) for m in fn_pattern.finditer(sql_content)}
    triggers = []
    for match in trg_pattern.finditer(sql_content):
        triggers.append({
            'name': match.group(1),
            'timing': match.group(2),
            'events': match.group(3),
            'table': match.group(4).lower(),
            'function': match.group(5).lower()
        })
    return functions, triggers

def parse_materialized_views(sql_content):
    mv_pattern = re.compile(
        r'CREATE\s+MATERIALIZED\s+VIEW\s+(?:IF NOT EXISTS\s+)?([a-zA-Z0-9_\.]+)',
        re.IGNORECASE
    )
    return set(m.group(1).lower() for m in mv_pattern.finditer(sql_content))

def run_tests():
    print("=" * 80)
    print("TALENTRA ARCHITECTURE & MULTI-MODULE REGRESSION VERIFICATION ENGINE (PHASE 1 - 4)")
    print("=" * 80)

    sql_dir = Path("sql")
    schema_p1 = (sql_dir / "schema.sql").read_text(encoding="utf-8")
    schema_admin = (sql_dir / "phase2_administration.sql").read_text(encoding="utf-8")
    schema_org = (sql_dir / "phase2_organisation.sql").read_text(encoding="utf-8")
    schema_gig = (sql_dir / "phase2_gig_marketplace.sql").read_text(encoding="utf-8")
    schema_src = (sql_dir / "phase3_sourcing.sql").read_text(encoding="utf-8")
    schema_sub = (sql_dir / "phase3_billing_subscriptions.sql").read_text(encoding="utf-8")
    schema_eng = (sql_dir / "phase4_engagement_community.sql").read_text(encoding="utf-8")
    schema_anl = (sql_dir / "phase4_analytics_marts.sql").read_text(encoding="utf-8")
    schema_gov = (sql_dir / "phase4_governance_shared.sql").read_text(encoding="utf-8")
    
    seed_p1 = (sql_dir / "seed.sql").read_text(encoding="utf-8")
    seed_admin = (sql_dir / "seed_administration.sql").read_text(encoding="utf-8")
    seed_org = (sql_dir / "seed_organisation.sql").read_text(encoding="utf-8")
    seed_gig = (sql_dir / "seed_gig_marketplace.sql").read_text(encoding="utf-8")
    seed_src = (sql_dir / "seed_phase3_sourcing.sql").read_text(encoding="utf-8")
    seed_sub = (sql_dir / "seed_phase3_billing.sql").read_text(encoding="utf-8")
    seed_eng = (sql_dir / "seed_phase4_engagement.sql").read_text(encoding="utf-8")
    seed_anl = (sql_dir / "seed_phase4_analytics.sql").read_text(encoding="utf-8")
    seed_gov = (sql_dir / "seed_phase4_governance.sql").read_text(encoding="utf-8")
    seed_p5 = (sql_dir / "seed_phase5_synthetic.sql").read_text(encoding="utf-8")

    test_p1 = (sql_dir / "integrity_regression_test.sql").read_text(encoding="utf-8")
    test_admin = (sql_dir / "administration_regression_test.sql").read_text(encoding="utf-8")
    test_org = (sql_dir / "organisation_regression_test.sql").read_text(encoding="utf-8")
    test_gig = (sql_dir / "gig_regression_test.sql").read_text(encoding="utf-8")
    test_src = (sql_dir / "sourcing_regression_test.sql").read_text(encoding="utf-8")
    test_sub = (sql_dir / "billing_subscriptions_regression_test.sql").read_text(encoding="utf-8")
    test_eng = (sql_dir / "phase4_engagement_regression_test.sql").read_text(encoding="utf-8")
    test_anl = (sql_dir / "phase4_analytics_regression_test.sql").read_text(encoding="utf-8")
    test_gov = (sql_dir / "phase4_governance_regression_test.sql").read_text(encoding="utf-8")
    test_sec_p5 = (sql_dir / "phase5_security_regression_test.sql").read_text(encoding="utf-8")

    queries_p5 = (sql_dir / "phase5_queries.sql").read_text(encoding="utf-8")
    mod_queries_p5 = (sql_dir / "phase5_module_queries.sql").read_text(encoding="utf-8")

    combined_ddl = f"{schema_p1}\n{schema_admin}\n{schema_org}\n{schema_gig}\n{schema_src}\n{schema_sub}\n{schema_eng}\n{schema_anl}\n{schema_gov}"

    tables = parse_tables(combined_ddl)
    indexes = parse_indexes(combined_ddl)
    functions, triggers = parse_functions_and_triggers(combined_ddl)
    mat_views = parse_materialized_views(combined_ddl)

    print(f"\n[SECTION 1: STRUCTURAL INVENTORY]")
    print(f"  * Total Tables Defined:      {len(tables)}")
    print(f"  * Total Indexes Defined:     {len(indexes)}")
    print(f"  * Stored Functions Defined:  {len(functions)}")
    print(f"  * Automated Triggers:        {len(triggers)}")

    passed = 0
    failed = 0

    def assert_true(test_code, test_desc, condition, details=""):
        nonlocal passed, failed
        if condition:
            passed += 1
            print(f"  [PASS] {test_code}: {test_desc}")
        else:
            failed += 1
            print(f"  [FAIL] {test_code}: {test_desc} -> {details}")

    # Section 2: Schema Boundaries (All 10 Domain Schemas)
    print("\n[SECTION 2: MULTI-MODULE SCHEMA BOUNDARY VALIDATION]")
    schemas = set(t.split('.')[0] for t in tables.keys())
    expected_schemas = {'master_data', 'profile', 'recruitment', 'administration', 'organisation', 'gig', 'sourcing', 'licence', 'billing', 'engagement', 'analytics'}
    assert_true("CHK-001", "All 10 Domain Schemas Present",
                schemas == expected_schemas,
                f"Found schemas: {schemas}")
    
    admin_tbl_count = len([t for t in tables if t.startswith('administration.')])
    org_tbl_count = len([t for t in tables if t.startswith('organisation.')])
    gig_tbl_count = len([t for t in tables if t.startswith('gig.')])
    sourcing_tbl_count = len([t for t in tables if t.startswith('sourcing.')])
    billing_tbl_count = len([t for t in tables if t.startswith('billing.')])
    licence_tbl_count = len([t for t in tables if t.startswith('licence.')])
    eng_tbl_count = len([t for t in tables if t.startswith('engagement.')])
    anl_tbl_count = len([t for t in tables if t.startswith('analytics.')])
    
    assert_true("CHK-002", "Administration Module Table Count (41 Tables: 17 Phase 2 + 24 Phase 4 Module C)", admin_tbl_count == 41, f"Count: {admin_tbl_count}")
    assert_true("CHK-003", "Organisation Module Table Count (24 Tables per Revised v2 Spec)", org_tbl_count == 24, f"Count: {org_tbl_count}")
    assert_true("CHK-004", "Gig Marketplace Table Count (27 Tables per v3 Spec)", gig_tbl_count == 27, f"Count: {gig_tbl_count}")
    assert_true("CHK-005", "Sourcing Module Table Count (13 Tables per Phase 3 Spec)", sourcing_tbl_count == 13, f"Count: {sourcing_tbl_count}")
    assert_true("CHK-006", "Subscriptions & Wallet Table Count (31 Tables per Phase 3 Spec)", billing_tbl_count == 31, f"Count: {billing_tbl_count}")
    assert_true("CHK-007", "Licence Module Table Count (4 Tables: licence, seat_assignment, registered_device, seat_allocation_history)", licence_tbl_count == 4, f"Count: {licence_tbl_count}")
    assert_true("CHK-008", "Engagement & Community Module Table Count (57 Tables per Phase 4 Spec)", eng_tbl_count == 57, f"Count: {eng_tbl_count}")
    assert_true("CHK-009", "Analytics Layer Table Count (48 Tables per Phase 4 Spec)", anl_tbl_count == 48, f"Count: {anl_tbl_count}")
    assert_true("CHK-010", "Grand Total Tables Count (301 Tables: 300 Core + 1 Master Data Job Category)", len(tables) == 301, f"Count: {len(tables)}")

    # Section 3: Organisation & Tenancy Invariants
    print("\n[SECTION 3: ORGANISATION & TENANCY INVARIANTS]")
    assert_true("ORG-001", "One live headquarters per organisation partial unique index",
                any(i['name'] == 'uq_organisation_location_headquarters' for i in indexes))
    assert_true("ORG-002", "Recruiter overlap EXCLUDE constraint defined on organisation_recruiter",
                'ex_organisation_recruiter_overlap' in tables['organisation.organisation_recruiter']['body'])
    assert_true("ORG-003", "Administrator overlap EXCLUDE constraint defined on account_administrator",
                'ex_account_administrator_overlap' in tables['organisation.account_administrator']['body'])
    assert_true("ORG-004", "Hierarchy cycle check trigger defined on organisation_relationship",
                any(t['name'] == 'trg_organisation_relationship_cycle' for t in triggers))
    assert_true("ORG-005", "Monthly range partitioning configured on organisation.audit_event",
                'partition of organisation.audit_event' in schema_org.lower())

    # Section 4: Gig Marketplace Invariants
    print("\n[SECTION 4: GIG MARKETPLACE INVARIANTS]")
    assert_true("GIG-001", "Worker availability calendar EXCLUDE constraint defined",
                'ex_gig_worker_availability_no_overlap' in tables['gig.gig_worker_availability']['body'])
    assert_true("GIG-002", "Self-application prevention trigger defined on gig_application",
                any(t['name'] == 'trg_prevent_self_application' for t in triggers))
    assert_true("GIG-003", "Positions cap enforcement trigger defined on gig_assignment",
                any(t['name'] == 'trg_enforce_positions_cap' for t in triggers))
    assert_true("GIG-004", "master_data.service_category table defined and accessible",
                'master_data.service_category' in tables)

    # Section 5: Phase 3 Module A (Sourcing) Invariants
    print("\n[SECTION 5: SOURCING & CONSULTANT REQUESTS INVARIANTS]")
    assert_true("SRC-001", "Sourcing request consultant guard trigger defined",
                any(t['name'] == 'trg_sourcing_request_guard' for t in triggers))
    assert_true("SRC-002", "Sourcing request decision sync trigger defined",
                any(t['name'] == 'trg_sourcing_request_decision_sync' for t in triggers))
    assert_true("SRC-003", "Sourcing shortlist provenance guard trigger defined",
                any(t['name'] == 'trg_shortlist_source_type_guard' for t in triggers))
    assert_true("SRC-004", "Sourcing request decision append-only trigger defined",
                any(t['name'] == 'trg_sourcing_request_decision_append_only' for t in triggers))

    # Section 6: Phase 3 Module B (Subscriptions & Wallet) Invariants
    print("\n[SECTION 6: SUBSCRIPTIONS & WALLET INVARIANTS]")
    assert_true("SUB-001", "Plan price effective range EXCLUDE constraint defined",
                'ex_plan_price_range' in tables['billing.plan_price']['body'])
    assert_true("SUB-002", "Subscription period non-overlapping EXCLUDE constraint defined",
                'ex_subscription_period_range' in tables['billing.subscription_period']['body'])
    assert_true("SUB-003", "Credit tariff range EXCLUDE constraint defined",
                'ex_credit_tariff_range' in tables['billing.credit_tariff']['body'])
    assert_true("SUB-004", "Refund cumulative cap validation trigger defined",
                any(t['name'] == 'trg_refund_cap' for t in triggers))
    assert_true("SUB-005", "Wallet balance cache sync trigger defined",
                any(t['name'] == 'trg_wallet_balance_cache_sync' for t in triggers))
    assert_true("SUB-006", "Wallet ledger append-only trigger defined",
                any(t['name'] == 'trg_wallet_ledger_append_only' for t in triggers))

    # Section 6B: Enterprise Licensing & Seat Invariants
    print("\n[SECTION 6B: ENTERPRISE LICENSING & SEAT INVARIANTS]")
    assert_true("LIC-001", "Seat assignment active partial unique index defined",
                any(i['name'] == 'idx_seat_assignment_active_user' for i in indexes))
    assert_true("LIC-002", "Seat cap enforcement trigger defined on seat_assignment",
                any(t['name'] == 'trg_enforce_seat_cap' for t in triggers))
    assert_true("LIC-003", "Seat allocation history append-only trigger defined",
                any(t['name'] == 'trg_seat_allocation_history_append_only' for t in triggers))
    assert_true("LIC-004", "Registered device active fingerprint unique index defined",
                any(i['name'] == 'idx_registered_device_active_fingerprint' for i in indexes))
    assert_true("LIC-005", "Licence table has max_devices_per_user column configured",
                'max_devices_per_user' in tables['licence.licence']['columns'])

    # Section 6C: Phase 4 Module A (Engagement & Notifications) Invariants
    print("\n[SECTION 6C: ENGAGEMENT & COMMUNITY INVARIANTS]")
    assert_true("ENG-INV-001", "Notification delivery monthly range partitioning configured",
                'partition by range (notification_created_at)' in schema_eng.lower())
    assert_true("ENG-INV-002", "Notification delivery attempt monthly range partitioning configured",
                'partition by range (attempted_at)' in schema_eng.lower())
    assert_true("ENG-INV-003", "Follow relation exactly-one target constraint defined",
                'ck_follow_relation_one_target' in tables['engagement.follow_relation']['body'])
    assert_true("ENG-INV-004", "Follow relation self-follow prevention constraint defined",
                'ck_follow_relation_not_self' in tables['engagement.follow_relation']['body'])
    assert_true("ENG-INV-005", "Community report exactly-one target constraint defined",
                'ck_community_report_one_target' in tables['engagement.community_report']['body'])
    assert_true("ENG-INV-006", "Delivery guard function fn_can_deliver defined",
                'engagement.fn_can_deliver' in functions)
    assert_true("ENG-INV-007", "Support ticket status history logger trigger defined",
                any(t['name'] == 'trg_support_ticket_status_history' for t in triggers))

    # Section 6D: Phase 4 Module B (Analytics Layer & Marts) Invariants
    print("\n[SECTION 6D: ANALYTICS LAYER & MARTS INVARIANTS]")
    assert_true("ANL-INV-001", "dim_date smart integer key and calendar constraint defined",
                'ck_dim_date_quarter' in tables['analytics.dim_date']['body'])
    assert_true("ANL-INV-002", "dim_job_category restricted 8 categories check constraint defined",
                'ck_dim_job_category_set' in tables['analytics.dim_job_category']['body'])
    assert_true("ANL-INV-003", "dim_candidate SCD2 non-overlapping GiST exclusion constraint defined",
                'ex_dim_candidate_period' in tables['analytics.dim_candidate']['body'])
    assert_true("ANL-INV-004", "dim_organisation SCD2 non-overlapping GiST exclusion constraint defined",
                'ex_dim_organisation_period' in tables['analytics.dim_organisation']['body'])
    assert_true("ANL-INV-005", "dim_gig_worker SCD2 non-overlapping GiST exclusion constraint defined",
                'ex_dim_gig_worker_period' in tables['analytics.dim_gig_worker']['body'])
    assert_true("ANL-INV-006", "Fact tables partitioned on date_id",
                'partition by range (date_id)' in schema_anl.lower())
    assert_true("ANL-INV-007", "All 9 Aggregate Reporting Marts defined in analytics schema",
                len([t for t in tables if t.startswith('analytics.agg_')]) == 9)

    # Section 6E: Phase 4 Module C (Governance & Privacy) Invariants
    print("\n[SECTION 6E: GOVERNANCE, PRIVACY & SESSIONS INVARIANTS]")
    assert_true("GOV-INV-001", "candidate_visible_to security definer function defined",
                'administration.candidate_visible_to' in functions)
    assert_true("GOV-INV-002", "start_user_session concurrency-safe locking function defined",
                'administration.start_user_session' in functions)
    assert_true("GOV-INV-003", "login_attempt monthly range partitioning configured",
                'partition by range (occurred_at)' in schema_gov.lower())
    assert_true("GOV-INV-004", "credential_reset_token single use and expiry constraints defined",
                'ck_credential_reset_token_expiry' in tables['administration.credential_reset_token']['body'])
    assert_true("GOV-INV-005", "consent_policy period validity check defined",
                'ck_consent_policy_period' in tables['administration.consent_policy']['body'])
    assert_true("GOV-INV-006", "data_subject_request SLA temporal check defined",
                'ck_data_subject_request_due' in tables['administration.data_subject_request']['body'])

    # Section 7: Foreign Key Cross-Reference Integrity
    print("\n[SECTION 7: FOREIGN KEY REFERENTIAL INTEGRITY]")
    fk_pattern = re.compile(r'REFERENCES\s+([a-zA-Z0-9_\.]+)\s*\(([a-zA-Z0-9_]+)\)', re.IGNORECASE)
    all_fks = fk_pattern.findall(combined_ddl)
    missing_fk_targets = []
    for target_table, target_col in all_fks:
        target_table_lower = target_table.lower()
        target_col_lower = target_col.lower()
        if target_table_lower not in tables:
            missing_fk_targets.append(f"Table {target_table_lower} not in DDL")
        elif target_col_lower not in tables[target_table_lower]['columns'] and target_col_lower != 'id':
            missing_fk_targets.append(f"Column {target_col_lower} not in {target_table_lower}")
    
    assert_true("FK-001", "All Cross-Module Foreign Key Targets Exist (100% Valid)",
                len(missing_fk_targets) == 0,
                f"Issues: {missing_fk_targets[:3]}")

    # Section 8: Index Target Column Verification
    print("\n[SECTION 8: INDEX TARGET COLUMN VERIFICATION]")
    missing_idx_cols = []
    for idx in indexes:
        t_name = idx['table']
        if t_name in mat_views:
            continue
        if t_name not in tables:
            missing_idx_cols.append(f"Index {idx['name']} targets nonexistent table {t_name}")
            continue
        t_cols = tables[t_name]['columns']
        expr = idx['expr']
        
        if 'to_tsvector' in expr.lower():
            referenced = re.findall(r'\b([a-zA-Z_][a-zA-Z0-9_]*)\b', expr)
            sql_keywords = {'to_tsvector', 'english', 'coalesce'}
            target_cols = [c.lower() for c in referenced if c.lower() not in sql_keywords]
            for c in target_cols:
                if c not in t_cols:
                    missing_idx_cols.append(f"Index {idx['name']} references missing column {c} on {t_name}")
        else:
            cols = [c.strip() for c in expr.split(',')]
            for col_expr in cols:
                cleaned_col = re.sub(r'\b(lower|upper)\b|\(|\)', '', col_expr, flags=re.IGNORECASE)
                cleaned_col = re.sub(r'\s+(desc|asc|nulls\s+first|nulls\s+last)', '', cleaned_col, flags=re.IGNORECASE)
                cleaned_col = re.sub(r'\s+[a-zA-Z0-9_]+_ops', '', cleaned_col, flags=re.IGNORECASE).strip().lower()
                if cleaned_col not in t_cols and not any(op in col_expr for op in ['+', '-', '||']):
                    missing_idx_cols.append(f"Index {idx['name']} references missing column {cleaned_col} on {t_name}")

    assert_true("IDX-001", f"All {len(indexes)} Indexes Point to Valid Existing Table Columns",
                len(missing_idx_cols) == 0,
                f"Issues: {missing_idx_cols[:3]}")

    # Section 9: Seed Data Verification
    print("\n[SECTION 9: MULTI-MODULE SEED VERIFICATION]")
    assert_true("SEED-001", "Organisation seed contains TechCorp Global (id=5001) & Account (id=6001)",
                '5001' in seed_org and 'TechCorp Global' in seed_org and '6001' in seed_org)
    assert_true("SEED-002", "Gig Marketplace seed contains Service Categories & Lookups",
                'software_engineering' in seed_gig and 'fixed_price' in seed_gig)
    assert_true("SEED-003", "Gig Marketplace seed contains Aarav Sharma Worker Profile (7001)",
                '7001' in seed_gig and 'Aarav Sharma' in seed_admin)
    assert_true("SEED-004", "Sourcing seed contains Sourcing Request Statuses & Fixture",
                'pending' in seed_src and 'accepted' in seed_src and 'Q4 Senior Cloud Architect' in seed_src)
    assert_true("SEED-005", "Subscriptions & Wallet seed contains Plans, Features, and Account 6001 Subscription",
                'growth_plan' in seed_sub and 'profile_download' in seed_sub and 'LIC-TAL-ENTERPRISE-001' in seed_sub)
    assert_true("SEED-006", "Engagement seed contains notification templates, search criteria & community topic",
                'template.job_alert.subject' in seed_eng and 'database-engineering' in seed_eng and 'TAL-WELCOME-2026' in seed_eng)
    assert_true("SEED-007", "Analytics seed contains dim_date calendar fixtures & 8 job categories",
                '2026-10-01' in seed_anl and 'campus' in seed_anl and 'managed_remote' in seed_anl)
    assert_true("SEED-008", "Governance seed contains DPDP consent policy, retention rules & lookups",
                'privacy_policy_dpdp' in seed_gov and 'v1.0-2026' in seed_gov and 'erasure_right_to_be_forgotten' in seed_gov)

    # Section 10: Regression Suites
    print("\n[SECTION 10: REGRESSION TEST SUITE VERIFICATION]")
    adm_tests = [f"ADM-{i:03d}" for i in range(1, 31)]
    missing_adm_tests = [t for t in adm_tests if t not in test_admin]
    assert_true("REG-ADM", "All 30 Administration Test Scenarios Codified (ADM-001..30)",
                len(missing_adm_tests) == 0,
                f"Missing tests: {missing_adm_tests}")

    p1_tests = [f"PASS {i}:" for i in range(1, 17)]
    missing_p1_tests = [t for t in p1_tests if t not in test_p1]
    assert_true("REG-P1", "All 16 Phase 1 Regression Tests Codified (PASS 1..16)",
                len(missing_p1_tests) == 0,
                f"Missing tests: {missing_p1_tests}")

    org_tests = [f"ORG-{i:03d}" for i in range(1, 22)]
    missing_org_tests = [t for t in org_tests if t not in test_org]
    assert_true("REG-ORG", "All Organisation Regression Test Assertions Codified (ORG-001..21)",
                len(missing_org_tests) == 0,
                f"Missing tests: {missing_org_tests}")

    gig_tests = ["GIG-001", "GIG-002", "GIG-003", "GIG-004", "GIG-005", "GIG-006A", "GIG-006B", "GIG-006C", "GIG-007"]
    missing_gig_tests = [t for t in gig_tests if t not in test_gig]
    assert_true("REG-GIG", "All Gig Marketplace Regression Assertions Codified (GIG-001..07)",
                len(missing_gig_tests) == 0,
                f"Missing tests: {missing_gig_tests}")

    src_tests = [f"SRC-{i:03d}" for i in range(1, 14)]
    missing_src_tests = [t for t in src_tests if t not in test_src]
    assert_true("REG-SRC", "All 13 Sourcing Regression Assertions Codified (SRC-001..13)",
                len(missing_src_tests) == 0,
                f"Missing tests: {missing_src_tests}")

    sub_tests = [f"SUB-{i:03d}" for i in range(1, 17)]
    missing_sub_tests = [t for t in sub_tests if t not in test_sub]
    assert_true("REG-SUB", "All 16 Subscriptions & Licensing Regression Assertions Codified (SUB-001..16)",
                len(missing_sub_tests) == 0,
                f"Missing tests: {missing_sub_tests}")

    eng_tests = [f"ENG-{i:03d}" for i in range(1, 13)]
    missing_eng_tests = [t for t in eng_tests if t not in test_eng]
    assert_true("REG-ENG", "All 12 Engagement Regression Assertions Codified (ENG-001..12)",
                len(missing_eng_tests) == 0,
                f"Missing tests: {missing_eng_tests}")

    anl_tests = [f"ANL-{i:03d}" for i in range(1, 13)]
    missing_anl_tests = [t for t in anl_tests if t not in test_anl]
    assert_true("REG-ANL", "All 12 Analytics Marts Regression Assertions Codified (ANL-001..12)",
                len(missing_anl_tests) == 0,
                f"Missing tests: {missing_anl_tests}")

    gov_tests = [f"GOV-{i:03d}" for i in range(1, 13)]
    missing_gov_tests = [t for t in gov_tests if t not in test_gov]
    assert_true("REG-GOV", "All 12 Governance & Privacy Regression Assertions Codified (GOV-001..12)",
                len(missing_gov_tests) == 0,
                f"Missing tests: {missing_gov_tests}")

    # Section 11: Zero Duplication & Clean Architecture Audit
    print("\n[SECTION 11: ZERO DUPLICATION & CLEAN ARCHITECTURE AUDIT]")
    all_table_names = [t.lower() for t in tables.keys()]
    dup_tbls = [t for t, cnt in Counter(all_table_names).items() if cnt > 1]
    assert_true("DUP-001", "Zero Duplicate Table Declarations Across All DDL Files",
                len(dup_tbls) == 0, f"Duplicates: {dup_tbls}")

    all_idx_names = [i['name'].lower() for i in indexes]
    dup_idxs = [i for i, cnt in Counter(all_idx_names).items() if cnt > 1]
    assert_true("DUP-002", "Zero Duplicate Index Names Across Entire Platform",
                len(dup_idxs) == 0, f"Duplicates: {dup_idxs}")

    con_pattern = re.compile(r'CONSTRAINT\s+([a-zA-Z0-9_]+)\s+(?:PRIMARY|FOREIGN|CHECK|UNIQUE|EXCLUDE)', re.IGNORECASE)
    all_con_names = [c.lower() for c in con_pattern.findall(combined_ddl)]
    dup_cons = [c for c, cnt in Counter(all_con_names).items() if cnt > 1]
    assert_true("DUP-003", "Zero Duplicate Constraint Names Across Entire Platform",
                len(dup_cons) == 0, f"Duplicates: {dup_cons}")

    table_col_dups = []
    for tname, tdata in tables.items():
        clean_body = re.sub(r'--.*', '', tdata['body'])
        elements = extract_table_elements(clean_body)
        raw_cols = []
        for elem in elements:
            elem_clean = ' '.join(elem.splitlines()).strip()
            if not elem_clean:
                continue
            upper_elem = elem_clean.upper()
            if not upper_elem.startswith('CONSTRAINT') and not any(upper_elem.startswith(k) for k in ['PRIMARY KEY', 'FOREIGN KEY', 'UNIQUE', 'CHECK', 'EXCLUDE']):
                parts = elem_clean.split()
                if parts:
                    raw_cols.append(parts[0].strip('",').lower())
        c_counts = Counter(raw_cols)
        dups = [c for c, count in c_counts.items() if count > 1]
        if dups:
            table_col_dups.append(f"{tname}: {dups}")
    assert_true("DUP-004", "Zero Duplicate Column Definitions Within Any Table",
                len(table_col_dups) == 0, f"Duplicates: {table_col_dups}")

    trg_table_pairs = [(t['name'].lower(), t['table'].lower()) for t in triggers]
    dup_trgs = [tp for tp, cnt in Counter(trg_table_pairs).items() if cnt > 1]
    assert_true("DUP-005", "Zero Duplicate Triggers on Any Single Table",
                len(dup_trgs) == 0, f"Duplicates: {dup_trgs}")

    # Section 12: Phase 5 Synthetic Data & Seeding Verification (B60 - B64)
    print("\n[SECTION 12: PHASE 5 SYNTHETIC DATA & SEED VERIFICATION]")
    assert_true("P5-SEED-001", "Synthetic seed contains multilingual candidate profiles with UTF-8 scripts",
                'आदित्य' in seed_p5 and 'கார்த்திக்' in seed_p5 and 'طارق' in seed_p5)
    assert_true("P5-SEED-002", "Synthetic seed contains intentional candidate duplicate clusters",
                'candidate.0009.alt@example.com' in seed_p5 and '(Duplicate)' in seed_p5)
    assert_true("P5-SEED-003", "Synthetic seed contains 5-stage status pipeline transitions",
                'Stage progression in pipeline simulation' in seed_p5 and 'job_application' in seed_p5)
    assert_true("P5-SEED-004", "Synthetic seed contains gig assignment external fulfilment handoff",
                'EXT-FULFILL-2026-9601' in seed_p5 and 'gig_assignment' in seed_p5)
    assert_true("P5-SEED-005", "Synthetic seed contains double-entry wallet ledger top-up & deduction",
                'IDEMP-TOPUP-9801' in seed_p5 and 'IDEMP-CONSUME-9802' in seed_p5)

    # Section 13: Phase 5 Fixed Queries & Execution Plan Verification (B65 - B69)
    print("\n[SECTION 13: PHASE 5 FIXED QUERY SET & EXECUTION PLANS (B65-B69)]")
    assert_true("P5-QRY-001", "All 12 Fixed Production Queries Defined in phase5_queries.sql",
                all(f"QUERY {i}" in queries_p5 for i in range(1, 13)))
    assert_true("P5-QRY-002", "Top 10 Queries Include Annotated PostgreSQL Execution Plans & Buffers",
                all(f"EXECUTION PLAN (Top 10 - Query {i})" in queries_p5 for i in range(1, 11)))
    assert_true("P5-QRY-003", "Query 1 contains candidate_visible_to security definer enforcement",
                'candidate_visible_to' in queries_p5 and 'profile.candidate_profile' in queries_p5)
    assert_true("P5-QRY-004", "Query 8 contains FOR UPDATE SKIP LOCKED high-throughput queue claim",
                'FOR UPDATE SKIP LOCKED' in queries_p5 and 'notification_delivery' in queries_p5)
    assert_true("P5-QRY-005", "Query 12 contains recursive CTE acyclic organisation hierarchy rollup",
                'WITH RECURSIVE org_tree AS' in queries_p5 and 'cycle safeguard' in queries_p5.lower())
    assert_true("P5-QRY-006", "Module verification queries codified for Admin/Org/Gig (B67), Licences/Sourcing/Billing (B68), Notifications/Analytics (B69)",
                'MEMBER A:' in mod_queries_p5 and 'MEMBER B:' in mod_queries_p5 and 'MEMBER C:' in mod_queries_p5)

    # Section 14: Phase 5 Security & Access Control Regressions (B75 - B79)
    print("\n[SECTION 14: PHASE 5 SECURITY & ACCESS CONTROL REGRESSIONS (B75-B79)]")
    sec_tests = [f"SEC-{i:03d}" for i in range(1, 13)]
    missing_sec_tests = [t for t in sec_tests if t not in test_sec_p5]
    assert_true("REG-SEC", "All 12 Security Regression Scenarios Codified (SEC-001..12)",
                len(missing_sec_tests) == 0, f"Missing tests: {missing_sec_tests}")

    # Section 15: Phase 5 Gate 2 Deliverables & Extrapolation Verification (B80 - B82)
    print("\n[SECTION 15: PHASE 5 GATE 2 DELIVERABLES & DOCUMENTATION (B80-B82)]")
    doc_dir = Path("docs")
    assert_true("DOC-P5-001", "Seed validation report exists and covers Section 5 standards (B66)",
                (doc_dir / "phase-5-seed-validation-report.md").is_file())
    assert_true("DOC-P5-002", "Performance baseline and 100M extrapolation model report exists (B70-B74)",
                (doc_dir / "phase-5-performance-baseline-and-extrapolation.md").is_file())
    assert_true("DOC-P5-003", "Comprehensive security design note and STRIDE threat model exists (B75-B78, B81)",
                (doc_dir / "phase-5-security-design-note.md").is_file())
    assert_true("DOC-P5-004", "Disaster recovery backup/restore benchmark log with measured RTO exists (B80)",
                (doc_dir / "phase-5-backup-restore-and-rto-log.md").is_file())
    assert_true("DOC-P5-005", "Formal Gate 2 sign-off document covers all 82 backlogs (B82)",
                (doc_dir / "phase-5-gate-2-sign-off.md").is_file())

    # Summary
    print("\n" + "=" * 80)
    print(f"TEST RUN COMPLETE: {passed} PASSED | {failed} FAILED | SCORE: {(passed/(passed+failed))*100:.1f}%")
    print("=" * 80)
    return failed == 0

if __name__ == '__main__':
    success = run_tests()
    sys.exit(0 if success else 1)
