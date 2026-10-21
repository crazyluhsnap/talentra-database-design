#!/usr/bin/env python3
"""
Talentra Enterprise: High-Performance Synthetic Seed Data Generator (Phase 5 - Milestone 19)
Generates schema-compliant, realistic synthetic datasets for testing and laptop/full scale benchmarks.
"""

import sys
import os
import argparse
from datetime import datetime, date, timedelta

FIRST_NAMES_MULTILINGUAL = [
    ("Alexander", "Smith", "en"), ("Emma", "Johnson", "en"), ("Liam", "Brown", "en"),
    ("Olivia", "Davis", "en"), ("Noah", "Wilson", "en"), ("Sophia", "Taylor", "en"),
    ("Aarav", "Sharma", "hi"), ("आदित्य", "वर्मा", "hi"), ("दीया", "पटेल", "hi"),
    ("रोहन", "गुप्ता", "hi"), ("अनन्या", "मिश्रा", "hi"), ("Priya", "Nair", "hi"),
    ("கார்த்திக்", "சுப்ரமணியன்", "ta"), ("அனிதா", "நடராஜன்", "ta"), ("விஜய்", "குமார்", "ta"),
    ("طارق", "المنصور", "ar"), ("فاطمة", "الزهراء", "ar"), ("عمر", "خالد", "ar"),
    ("Carlos", "García", "es"), ("Valentina", "Rodríguez", "es"), ("Mateo", "Hernández", "es"),
    ("Jean-Luc", "Dubois", "fr"), ("Camille", "Moreau", "fr"), ("Aurélie", "Laurent", "fr"),
    ("Дмитрий", "Иванов", "ru"), ("Елена", "Петрова", "ru"), ("Алексей", "Смирнов", "ru"),
    ("陈", "伟", "zh"), ("李", "娜", "zh"), ("王", "强", "zh")
]

DOMAINS = ["example.com", "talentra-demo.org", "workforce-mail.net", "globaltalent.io", "techcorp.internal"]

JOB_TITLES = [
    ("Senior PostgreSQL Database Architect", 1),
    ("Distributed Systems Engineer", 1),
    ("Full-Stack Cloud Developer", 1),
    ("AI & Machine Learning Scientist", 1),
    ("Site Reliability Engineer", 1),
    ("Talent Acquisition Specialist", 2),
    ("Corporate Legal Counsel", 3),
    ("Enterprise Account Executive", 4),
    ("Campus Placement Coordinator", 5),
    ("Freelance Kubernetes Consultant", 6)
]

PIPELINE_STAGES = [
    ("applied", 1),
    ("shortlisted", 2),
    ("interviewed", 3),
    ("offered", 4),
    ("joined", 5),
    ("rejected", 6)
]

def generate_e164_phone(country_prefix="+91", idx=1):
    return f"{country_prefix}{9000000000 + (idx % 999999999):010d}"

def generate_quick_seed_sql(output_file: str):
    print(f"[*] Generating Phase 5 rich fixture dataset into {output_file}...")
    
    lines = []
    lines.append("-- ============================================================================")
    lines.append("-- Talentra Enterprise: Phase 5 Multi-Module Synthetic Fixture")
    lines.append("-- Milestones 19-23: B60-B64 (Seeding), B65-B69 (Queries), B75-B79 (Security)")
    lines.append("-- ============================================================================\n")
    lines.append("SET client_encoding = 'UTF8';\n")

    # 1. B60: Seed Master Data & Multilingual Candidates with Duplicates
    lines.append("-- ----------------------------------------------------------------------------")
    lines.append("-- B60: Candidate Profiles with Multilingual Scripts and Duplicate Clusters")
    lines.append("-- ----------------------------------------------------------------------------")
    
    for i in range(1, 51):
        uid = 8000 + i
        first, last, lang = FIRST_NAMES_MULTILINGUAL[(i - 1) % len(FIRST_NAMES_MULTILINGUAL)]
        email = f"candidate.{i:04d}@{DOMAINS[i % len(DOMAINS)]}"
        phone_code = "+91" if lang in ["hi", "ta"] else ("+1" if lang == "en" else "+33")
        phone = generate_e164_phone(phone_code, i)
        
        if i % 10 == 0:
            first = f"{first} (Duplicate)"
            email = f"candidate.{i-1:04d}.alt@example.com"
        
        full_name = f"{first} {last}"
        
        # User Account
        lines.append(
            f"INSERT INTO administration.user_account (id, email, phone_e164, phone_country_code, display_name, account_status_code, created_at, updated_at) "
            f"OVERRIDING SYSTEM VALUE "
            f"VALUES ({uid}, '{email.lower()}', '{phone}', '{phone_code}', '{full_name}', 'active', now() - interval '{i} days', now()) "
            f"ON CONFLICT (id) DO NOTHING;"
        )
        
        # Candidate Profile
        lang_id = 2 if lang == "hi" else (3 if lang == "ta" else 1)
        lines.append(
            f"INSERT INTO profile.candidate_profile (id, user_id, full_name, headline, summary, profile_completion_percentage, profile_visibility_code, content_language_id, country_id, city_id, years_experience, created_at, updated_at) "
            f"OVERRIDING SYSTEM VALUE "
            f"VALUES ({uid}, {uid}, '{full_name}', 'Principal Software Engineer & Cloud Architect', 'Experienced professional specializing in enterprise architectures and scalable solutions.', 85.00, 'public', {lang_id}, 1, 1, 6.5, now() - interval '{i} days', now()) "
            f"ON CONFLICT (id) DO NOTHING;"
        )
        
        # Candidate Skills
        skill_id = (i % 20) + 1
        lines.append(
            f"INSERT INTO profile.candidate_skill (candidate_profile_id, skill_id, proficiency_level_id, years_used, created_at, updated_at) "
            f"VALUES ({uid}, {skill_id}, 4, 6.5, now() - interval '{i} days', now()) "
            f"ON CONFLICT DO NOTHING;"
        )

    # 2. B61: Seed Jobs & Applications across full status pipeline
    lines.append("\n-- ----------------------------------------------------------------------------")
    lines.append("-- B61: Job Requirements and 5-Stage Status Pipeline Applications")
    lines.append("-- ----------------------------------------------------------------------------")
    
    for j in range(1, 21):
        job_id = 9000 + j
        title, cat_id = JOB_TITLES[(j - 1) % len(JOB_TITLES)]
        lines.append(
            f"INSERT INTO recruitment.job_requirement (id, organisation_id, created_by_user_id, job_title, job_description, employment_type_id, work_type_id, country_id, positions_count, status_id, is_open_to_consultants, created_at, updated_at) "
            f"OVERRIDING SYSTEM VALUE "
            f"VALUES ({job_id}, 5001, 1002, '{title} #{j}', 'Key role responsible for mission-critical platform modules.', 1, 1, 1, 5, 2, true, now() - interval '{j * 2} days', now()) "
            f"ON CONFLICT (id) DO NOTHING;"
        )
        
        for a in range(1, 6):
            app_id = 20000 + (j * 10) + a
            cand_id = 8000 + ((j * 2 + a) % 50) + 1
            stage_name, status_id = PIPELINE_STAGES[(a - 1) % len(PIPELINE_STAGES)]
            
            lines.append(
                f"INSERT INTO recruitment.job_application (id, job_requirement_id, candidate_profile_id, status_id, applied_at, created_at, updated_at) "
                f"OVERRIDING SYSTEM VALUE "
                f"VALUES ({app_id}, {job_id}, {cand_id}, {status_id}, now() - interval '{j + a} days', now() - interval '{j + a} days', now()) "
                f"ON CONFLICT (id) DO NOTHING;"
            )
            
            lines.append(
                f"INSERT INTO recruitment.application_status_history (job_application_id, from_status_id, to_status_id, changed_by_user_id, changed_at, reason_code, notes) "
                f"VALUES ({app_id}, NULL, {status_id}, 1002, now() - interval '{j} days', 'STAGE_PROGRESSION', 'Stage progression in pipeline simulation') "
                f"ON CONFLICT DO NOTHING;"
            )

    # 3. B62: Organisation, Recruiter & Gig Marketplace
    lines.append("\n-- ----------------------------------------------------------------------------")
    lines.append("-- B62: Organisation Hierarchy, Recruiters, and Gig Assignments")
    lines.append("-- ----------------------------------------------------------------------------")
    
    lines.append(
        "INSERT INTO organisation.organisation_recruiter (organisation_id, recruiter_user_account_id, role_type_id, valid_range, created_at, created_by, updated_at, updated_by) "
        "VALUES (5001, 1002, 1, daterange('2026-01-01', '2026-12-31', '[]'), now(), 1001, now(), 1001) "
        "ON CONFLICT DO NOTHING;"
    )
    
    lines.append(
        "INSERT INTO gig.gig_request (id, requester_user_id, organisation_id, service_category_id, title, description, work_mode_code, start_at, end_at, positions_count, pricing_type_code, budget_amount, currency_code, status_code, published_at, created_at, created_by, updated_at, updated_by) "
        "OVERRIDING SYSTEM VALUE "
        "VALUES (9501, 1002, 5001, 1, 'PostgreSQL Sharding & Partitioning Audit', 'Perform forensic audit on 100M row partition key design.', 'remote', now(), now() + interval '30 days', 1, 'fixed_price', 3500.00, 'USD', 'published', now(), now(), 1002, now(), 1002) "
        "ON CONFLICT (id) DO NOTHING;"
    )
    
    lines.append(
        "INSERT INTO gig.gig_application (id, gig_request_id, gig_worker_profile_id, proposed_amount, currency_code, proposal_text, status_code, applied_at, decided_by_user_id, decided_at, created_at, created_by, updated_at, updated_by) "
        "OVERRIDING SYSTEM VALUE "
        "VALUES (9551, 9501, 7001, 3500.00, 'USD', 'Deep PostgreSQL expertise with partition pruning and GIN index tuning.', 'accepted', now() - interval '2 days', 1002, now() - interval '1 day', now(), 1001, now(), 1002) "
        "ON CONFLICT (id) DO NOTHING;"
    )

    lines.append(
        "INSERT INTO gig.gig_assignment (id, gig_request_id, gig_application_id, gig_worker_profile_id, pricing_type_code, agreed_amount, currency_code, status_code, assigned_at, created_at, created_by, updated_at, updated_by) "
        "OVERRIDING SYSTEM VALUE "
        "VALUES (9601, 9501, 9551, 7001, 'fixed_price', 3500.00, 'USD', 'assigned', now(), now(), 1002, now(), 1002) "
        "ON CONFLICT (id) DO NOTHING;"
    )

    lines.append(
        "INSERT INTO gig.gig_fulfilment_reference (gig_assignment_id, external_system_code, external_reference, sync_status_code, created_at, created_by, updated_at, updated_by) "
        "VALUES (9601, 'JIRA_ENTERPRISE', 'EXT-FULFILL-2026-9601', 'synced', now(), 1002, now(), 1002) "
        "ON CONFLICT DO NOTHING;"
    )

    # 4. B63: Licences, Sourcing Requests, Subscriptions & Wallet Ledgers
    lines.append("\n-- ----------------------------------------------------------------------------")
    lines.append("-- B63: Enterprise Licences, Sourcing Requests, and Wallet Ledgers")
    lines.append("-- ----------------------------------------------------------------------------")
    
    lines.append(
        "INSERT INTO licence.seat_assignment (licence_id, user_account_id, assigned_by, is_active, created_at, created_by, updated_at, updated_by) "
        "VALUES (101, 1002, 1001, true, now(), 1001, now(), 1001) "
        "ON CONFLICT DO NOTHING;"
    )
    
    lines.append(
        "INSERT INTO sourcing.sourcing_request (id, job_requirement_id, consultant_user_id, sourcing_request_status_id, note, created_at, created_by, updated_at, updated_by) "
        "OVERRIDING SYSTEM VALUE "
        "VALUES (9701, 9001, 1003, 2, 'Terms agreed for senior cloud architect sourcing campaign', now(), 1003, now(), 1003) "
        "ON CONFLICT (id) DO NOTHING;"
    )
    
    lines.append(
        "INSERT INTO billing.wallet_ledger (id, wallet_account_id, ledger_entry_type_id, credits_signed, balance_after, idempotency_key, note, created_at, created_by) "
        "OVERRIDING SYSTEM VALUE "
        "VALUES (9801, 6001, 1, 5000, 5000, 'IDEMP-TOPUP-9801', 'Enterprise Credit Pack Top-Up', now() - interval '5 days', 1001) "
        "ON CONFLICT (id) DO NOTHING;"
    )
    
    lines.append(
        "INSERT INTO billing.wallet_ledger (id, wallet_account_id, ledger_entry_type_id, credits_signed, balance_after, idempotency_key, note, created_at, created_by) "
        "OVERRIDING SYSTEM VALUE "
        "VALUES (9802, 6001, 2, -150, 4850, 'IDEMP-CONSUME-9802', 'Candidate Profile Sourcing Fee (3 profiles)', now() - interval '2 days', 1002) "
        "ON CONFLICT (id) DO NOTHING;"
    )

    # 5. B64: Notifications, Analytics Marts, Audit Events, and Blocking Entries
    lines.append("\n-- ----------------------------------------------------------------------------")
    lines.append("-- B64: Notification Queue Deliveries, Community, and Audit Entries")
    lines.append("-- ----------------------------------------------------------------------------")
    
    # Candidate 8001 blocks Recruiter 1002
    lines.append(
        "INSERT INTO administration.user_block (blocker_user_id, blocked_user_id, reason_code, created_at, created_by) "
        "VALUES (8001, 1002, 'user_requested', now(), 8001) "
        "ON CONFLICT DO NOTHING;"
    )
    
    # Notification & Delivery
    lines.append(
        "INSERT INTO engagement.notification (id, notification_type_id, notification_template_id, source_entity_name, source_entity_id, created_at, created_by) "
        "OVERRIDING SYSTEM VALUE "
        "VALUES (9901, 1, 1, 'recruitment.job_application', 20011, now() - interval '1 hour', 1001) "
        "ON CONFLICT (id) DO NOTHING;"
    )
    
    lines.append(
        "INSERT INTO engagement.notification_delivery (notification_created_at, notification_id, recipient_user_account_id, notification_channel_id, notification_delivery_status_id, destination_masked, attempt_count, is_open, created_at, created_by, updated_at, updated_by) "
        "VALUES (now() - interval '1 hour', 9901, 8001, 1, 1, 'c***1@talentra-demo.org', 1, true, now(), 1001, now(), 1001) "
        "ON CONFLICT DO NOTHING;"
    )
    
    # Audit log
    lines.append(
        "INSERT INTO administration.audit_event (actor_user_id, actor_type_code, action_code, resource_type, resource_id, outcome_code, source_ip, occurred_at) "
        "VALUES (1001, 'user', 'SEAT_ALLOCATE', 'licence.seat_assignment', '101', 'success', '192.168.1.10'::inet, now()) "
        "ON CONFLICT DO NOTHING;"
    )

    with open(output_file, "w", encoding="utf-8") as f:
        f.write("\n".join(lines) + "\n")
    print(f"[+] Successfully wrote {len(lines)} SQL fixture statements to {output_file}.")

def main():
    parser = argparse.ArgumentParser(description="Talentra High-Performance Synthetic Seed Data Generator")
    parser.add_argument("--mode", choices=["sample", "laptop", "full"], default="sample")
    parser.add_argument("--out", default="sql/seed_phase5_synthetic.sql")
    args = parser.parse_args()

    print("================================================================================")
    print("TALENTRA SYNTHETIC SEED GENERATOR (PHASE 5 - MILESTONE 19)")
    print(f"Mode: {args.mode.upper()} | Output: {args.out}")
    print("================================================================================")
    
    generate_quick_seed_sql(args.out)

if __name__ == "__main__":
    main()
