import re
import glob

def inspect():
    sql_files = [
        'sql/schema.sql',
        'sql/phase2_administration.sql',
        'sql/phase2_organisation.sql',
        'sql/phase2_gig_marketplace.sql',
        'sql/phase3_sourcing.sql',
        'sql/phase3_billing_subscriptions.sql'
    ]
    all_sql = ""
    for file_path in sql_files:
        try:
            with open(file_path, 'r', encoding='utf-8') as f:
                all_sql += f.read() + "\n"
        except FileNotFoundError:
            pass

    # Find schemas
    schemas = sorted(list(set(re.findall(r'CREATE SCHEMA IF NOT EXISTS\s+(\w+);', all_sql, re.IGNORECASE))))
    
    # Find tables
    table_pattern = re.compile(r'CREATE TABLE\s+([a-zA-Z0-9_\.]+)\s*\((.*?)\);', re.DOTALL | re.IGNORECASE)
    tables = table_pattern.findall(all_sql)

    print("=" * 70)
    print("TALENTRA DATABASE SCHEMA INSPECTOR (FULL PHASE 1, 2 & 3)")
    print("=" * 70)
    print(f"Schemas Defined ({len(schemas)}): {', '.join(schemas)}")
    print(f"Total Tables Created in DDL: {len(tables)}\n")

    schema_tables = {}
    for tbl_name, body in tables:
        schema = tbl_name.split('.')[0] if '.' in tbl_name else 'public'
        raw_name = tbl_name.split('.')[1] if '.' in tbl_name else tbl_name
        
        # Count columns (lines that don't start with CONSTRAINT)
        lines = [line.strip().rstrip(',') for line in body.splitlines() if line.strip()]
        cols = [l for l in lines if not l.upper().startswith('CONSTRAINT')]
        schema_tables.setdefault(schema, []).append((raw_name, len(cols)))

    for schema, tbls in schema_tables.items():
        print(f"Schema: [{schema}] ({len(tbls)} tables)")
        print("-" * 70)
        print(f"{'#':<4} {'Table Name':<38} {'Columns'}")
        print("-" * 70)
        for i, (tbl, count) in enumerate(tbls, 1):
            print(f"{i:<4} {tbl:<38} {count} columns")
        print()

    # Indexes & Triggers
    indexes = re.findall(r'CREATE (?:UNIQUE )?INDEX\s+(\w+)', all_sql, re.IGNORECASE)
    triggers = re.findall(r'CREATE TRIGGER\s+(\w+)', all_sql, re.IGNORECASE)
    print("=" * 70)
    print(f"Summary: {len(tables)} Tables | {len(indexes)} Indexes | {len(triggers)} Automated Triggers")
    print("=" * 70)

if __name__ == '__main__':
    inspect()
