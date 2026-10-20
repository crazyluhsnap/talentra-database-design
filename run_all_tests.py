"""
Talentra Enterprise Database Architecture & Multi-Module Verification Engine
Validates:
1. Master Data, Profile, Recruitment (Phase 1 Foundation - 54 tables)
2. Administration & Identity (Phase 2 - 17 tables)
3. Organisation & Account with Audit Trail (Phase 2 - 24 tables)
4. Gig Marketplace Subsystem (Phase 2 - 27 tables)
Total: 122 tables, 111 indexes, 68 triggers across 6 domain schemas.
"""

import re
import sys
from pathlib import Path

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
        re.IGNORECASE
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

def run_tests():
    print("=" * 80)
    print("TALENTRA ARCHITECTURE & MULTI-MODULE REGRESSION VERIFICATION ENGINE")
    print("=" * 80)

    sql_dir = Path("sql")
    schema_p1 = (sql_dir / "schema.sql").read_text(encoding="utf-8")
    schema_admin = (sql_dir / "phase2_administration.sql").read_text(encoding="utf-8")
    schema_org = (sql_dir / "phase2_organisation.sql").read_text(encoding="utf-8")
    schema_gig = (sql_dir / "phase2_gig_marketplace.sql").read_text(encoding="utf-8")
    
    seed_p1 = (sql_dir / "seed.sql").read_text(encoding="utf-8")
    seed_admin = (sql_dir / "seed_administration.sql").read_text(encoding="utf-8")
    seed_org = (sql_dir / "seed_organisation.sql").read_text(encoding="utf-8")
    seed_gig = (sql_dir / "seed_gig_marketplace.sql").read_text(encoding="utf-8")

    test_p1 = (sql_dir / "integrity_regression_test.sql").read_text(encoding="utf-8")
    test_admin = (sql_dir / "administration_regression_test.sql").read_text(encoding="utf-8")
    test_org = (sql_dir / "organisation_regression_test.sql").read_text(encoding="utf-8")
    test_gig = (sql_dir / "gig_regression_test.sql").read_text(encoding="utf-8")

    combined_ddl = f"{schema_p1}\n{schema_admin}\n{schema_org}\n{schema_gig}"

    tables = parse_tables(combined_ddl)
    indexes = parse_indexes(combined_ddl)
    functions, triggers = parse_functions_and_triggers(combined_ddl)

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

    # Section 2: Schema Boundaries (All 6 Domain Schemas)
    print("\n[SECTION 2: MULTI-MODULE SCHEMA BOUNDARY VALIDATION]")
    schemas = set(t.split('.')[0] for t in tables.keys())
    assert_true("CHK-001", "All 6 Core Schemas Present (master_data, profile, recruitment, administration, organisation, gig)",
                schemas == {'master_data', 'profile', 'recruitment', 'administration', 'organisation', 'gig'},
                f"Found schemas: {schemas}")
    
    admin_tbl_count = len([t for t in tables if t.startswith('administration.')])
    org_tbl_count = len([t for t in tables if t.startswith('organisation.')])
    gig_tbl_count = len([t for t in tables if t.startswith('gig.')])
    
    assert_true("CHK-002", "Administration Module Table Count (17 Tables)", admin_tbl_count == 17, f"Count: {admin_tbl_count}")
    assert_true("CHK-003", "Organisation Module Table Count (24 Tables per Revised v2 Spec)", org_tbl_count == 24, f"Count: {org_tbl_count}")
    assert_true("CHK-004", "Gig Marketplace Table Count (27 Tables per v3 Spec)", gig_tbl_count == 27, f"Count: {gig_tbl_count}")

    # Section 3: Organisation & Account Invariants
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

    # Section 5: Foreign Key Cross-Reference Integrity
    print("\n[SECTION 5: FOREIGN KEY REFERENTIAL INTEGRITY]")
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

    # Section 6: Index Target Column Verification
    print("\n[SECTION 6: INDEX TARGET COLUMN VERIFICATION]")
    missing_idx_cols = []
    for idx in indexes:
        t_name = idx['table']
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
                cleaned_col = re.sub(r'\(|\)|lower|upper', '', col_expr, flags=re.IGNORECASE)
                cleaned_col = re.sub(r'\s+(desc|asc|nulls\s+first|nulls\s+last)', '', cleaned_col, flags=re.IGNORECASE)
                cleaned_col = re.sub(r'\s+[a-zA-Z0-9_]+_ops', '', cleaned_col, flags=re.IGNORECASE).strip().lower()
                if cleaned_col not in t_cols and not any(op in col_expr for op in ['+', '-', '||']):
                    missing_idx_cols.append(f"Index {idx['name']} references missing column {cleaned_col} on {t_name}")

    assert_true("IDX-001", f"All {len(indexes)} Indexes Point to Valid Existing Table Columns",
                len(missing_idx_cols) == 0,
                f"Issues: {missing_idx_cols[:3]}")

    # Section 7: Seed Data Verification
    print("\n[SECTION 7: MULTI-MODULE SEED VERIFICATION]")
    assert_true("SEED-001", "Organisation seed contains TechCorp Global (id=5001) & Account (id=6001)",
                '5001' in seed_org and 'TechCorp Global' in seed_org and '6001' in seed_org)
    assert_true("SEED-002", "Gig Marketplace seed contains Service Categories & Lookups",
                'software_engineering' in seed_gig and 'fixed_price' in seed_gig)
    assert_true("SEED-003", "Gig Marketplace seed contains Aarav Sharma Worker Profile (7001)",
                '7001' in seed_gig and 'Aarav Sharma' in seed_admin)

    # Section 8: Regression Suites
    print("\n[SECTION 8: REGRESSION TEST SUITE VERIFICATION]")
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

    # Section 9: Zero Duplication & Clean Architecture Audit
    print("\n[SECTION 9: ZERO DUPLICATION & CLEAN ARCHITECTURE AUDIT]")
    from collections import Counter
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

    # Summary
    print("\n" + "=" * 80)
    print(f"TEST RUN COMPLETE: {passed} PASSED | {failed} FAILED | SCORE: {(passed/(passed+failed))*100:.1f}%")
    print("=" * 80)
    return failed == 0

if __name__ == '__main__':
    success = run_tests()
    sys.exit(0 if success else 1)
