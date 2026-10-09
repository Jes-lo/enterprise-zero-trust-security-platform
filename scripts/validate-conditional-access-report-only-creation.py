#!/usr/bin/env python3

import json
import re
import sys
from pathlib import Path


def fail(message: str) -> None:
    raise SystemExit(f"FAIL: {message}")


if len(sys.argv) != 3:
    fail(
        "usage: validate-conditional-access-report-only-creation.py "
        "<config.json> <evidence.json>"
    )


config_path = Path(sys.argv[1])
evidence_path = Path(sys.argv[2])

config_raw = config_path.read_text()
evidence_raw = evidence_path.read_text()

config = json.loads(config_raw)
evidence = json.loads(evidence_raw)

if config["feature"] != "6" or config["phase"] not in {"6B", "6B-R1", "6C", "6D"}:
    fail("unexpected Feature 6 lifecycle state")

current = config["current_state"]

if current["security_defaults_enabled"] is not True:
    fail("Security Defaults must remain enabled")

if current["conditional_access_policy_count"] != 4:
    fail("exactly four CA policies required")

if current["report_only_policy_count"] != 4:
    fail("all four CA policies must be report-only")

if current["enabled_conditional_access_policy_count"] != 0:
    fail("no CA policy may be enforced")


expected = {
    "CA-001": "PLAB-CA-001 - Require MFA for all users",
    "CA-002": "PLAB-CA-002 - Require MFA for privileged administration",
    "CA-003": "PLAB-CA-003 - Block legacy authentication",
    "CA-004": "PLAB-CA-004 - Require MFA for Azure management",
}

policies = config["planned_policies"]

if len(policies) != 4:
    fail("unexpected policy count in config")

if {p["id"] for p in policies} != set(expected):
    fail("policy IDs changed")

for policy in policies:
    policy_id = policy["id"]

    if policy["tenant_display_name"] != expected[policy_id]:
        fail(f"{policy_id} tenant display name changed")

    if policy["created"] is not True:
        fail(f"{policy_id} not marked created")

    if policy["current_mode"] != "report-only":
        fail(f"{policy_id} not report-only")

    if policy["enabled"] is not False:
        fail(f"{policy_id} incorrectly marked enabled")

    if policy["planned_initial_mode"] != "report-only":
        fail(f"{policy_id} no longer starts report-only")


by_id = {p["id"]: p for p in policies}

expected_current_ca004_target = (
    "Windows Azure Service Management API"
    if config["phase"] == "6B"
    else "Microsoft Admin Portals"
)

if (
    by_id["CA-004"]["target_resource_display_name"]
    != expected_current_ca004_target
):
    fail("CA-004 current resource changed")

if (
    by_id["CA-003"]["client_app_condition"]
    != "legacy-authentication-clients"
):
    fail("CA-003 legacy condition changed")

if by_id["CA-003"]["grant_control"] != "block":
    fail("CA-003 no longer blocks legacy authentication")


creation = config["report_only_creation"]

if creation["completed"] is not True:
    fail("6B creation not marked complete")

if creation["policy_creation_count"] != 4:
    fail("creation count is not four")

if creation["report_only_policy_count"] != 4:
    fail("report-only count is not four")

if creation["enabled_policy_count"] != 0:
    fail("enforcement recorded during 6B")

if creation["security_defaults_remained_enabled"] is not True:
    fail("Security Defaults preservation missing")

if creation["pilot_group_remained_empty"] is not True:
    fail("pilot group changed")

if creation["tenant_write_count"] != 4:
    fail("expected exactly four Feature 6B tenant writes")


pilot = config["pilot_strategy"]

if pilot["current_member_count"] != 0:
    fail("pilot group is no longer empty")

if pilot["policy_enforcement_authorized"] is not False:
    fail("policy enforcement prematurely authorized")

if pilot["pilot_membership_change_authorized"] is not False:
    fail("pilot membership prematurely authorized")

if any(config["authorization"].values()):
    fail("future write authorization leaked into config")


if evidence["feature"] != "6" or evidence["phase"] != "6B":
    fail("unexpected evidence lifecycle state")

created = evidence["created_policies"]

if len(created) != 4:
    fail("evidence policy count is not four")

if {item["id"] for item in created} != set(expected):
    fail("evidence policy IDs changed")

for item in created:
    pid = item["id"]

    if item["display_name"] != expected[pid]:
        fail(f"{pid} evidence display name changed")

    if pid == "CA-004":
        if item["target"] != "Windows Azure Active Directory":
            fail("historical CA-004 initial target is inaccurate")

    if item["mode"] != "report-only":
        fail(f"{pid} evidence not report-only")

    if item["enforced"] is not False:
        fail(f"{pid} evidence incorrectly claims enforcement")

    if item["emergency_exclusions"] != 2:
        fail(f"{pid} emergency exclusion count changed")


post = evidence["post_write_state"]

if post["security_defaults_enabled"] is not True:
    fail("evidence says Security Defaults disabled")

if post["conditional_access_policy_count"] != 4:
    fail("evidence CA policy count invalid")

if post["report_only_policy_count"] != 4:
    fail("evidence report-only count invalid")

if post["enabled_policy_count"] != 0:
    fail("evidence records enforced CA policy")

if post["ca_pilot_group_member_count"] != 0:
    fail("pilot group changed")

if any(evidence["protected_state"].values()):
    fail("protected tenant state changed")


activity = evidence["write_activity"]

if activity["tenant_writes"] != 4:
    fail("evidence write count must equal four")

if activity["conditional_access_policy_creations"] != 4:
    fail("exactly four policy creations required")

for key in (
    "conditional_access_policy_modifications_after_creation",
    "conditional_access_policy_enablements",
    "security_defaults_modifications",
    "group_membership_modifications",
    "role_modifications",
    "license_modifications",
    "authentication_method_modifications",
):
    if activity[key] != 0:
        fail(f"unauthorized Feature 6B activity: {key}")

if any(evidence["future_authorization"].values()):
    fail("future enforcement/cutover authorization leaked into evidence")

if any(evidence["privacy"].values()):
    fail("privacy control violation")


email = re.compile(
    r"[A-Za-z0-9._%+-]+@"
    r"[A-Za-z0-9.-]+\.[A-Za-z]{2,}"
)

guid = re.compile(
    r"\b"
    r"[0-9A-Fa-f]{8}-"
    r"[0-9A-Fa-f]{4}-"
    r"[0-9A-Fa-f]{4}-"
    r"[0-9A-Fa-f]{4}-"
    r"[0-9A-Fa-f]{12}"
    r"\b"
)

for name, raw in (
    ("config", config_raw),
    ("evidence", evidence_raw),
):
    if email.search(raw):
        fail(f"complete UPN/email detected in {name}")

    if guid.search(raw):
        fail(f"GUID detected in {name}")


print("PASS: Feature 6B report-only creation state valid.")
print("PASS: exactly four CA policies recorded.")
print("PASS: all four CA policies are report-only.")
print("PASS: zero CA policies are enforced.")
print("PASS: Security Defaults remains enabled.")
print("PASS: pilot group remains empty.")
print("PASS: exactly four tenant writes recorded.")
print("PASS: future enforcement remains unauthorized.")
print("PASS: Security Defaults cutover remains unauthorized.")
print("PASS: no tenant identifier or secret detected.")
