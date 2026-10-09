#!/usr/bin/env python3

import json
import re
import sys
from pathlib import Path


def fail(message: str) -> None:
    raise SystemExit(f"FAIL: {message}")


if len(sys.argv) != 4:
    fail(
        "usage: validate-conditional-access-ca004-target-correction.py "
        "<config.json> <historical-evidence.json> "
        "<correction-evidence.json>"
    )


config_path = Path(sys.argv[1])
historical_path = Path(sys.argv[2])
correction_path = Path(sys.argv[3])

config_raw = config_path.read_text()
historical_raw = historical_path.read_text()
correction_raw = correction_path.read_text()

config = json.loads(config_raw)
historical = json.loads(historical_raw)
correction = json.loads(correction_raw)


if config["feature"] != "6":
    fail("unexpected feature")

if config["phase"] not in {"6B-R1", "6C", "6D"}:
    fail("Feature 6 lifecycle is earlier than 6B-R1")


policies = {
    item["id"]: item
    for item in config["planned_policies"]
}

if set(policies) != {
    "CA-001",
    "CA-002",
    "CA-003",
    "CA-004",
}:
    fail("unexpected Conditional Access policy set")


ca004 = policies["CA-004"]

if (
    ca004["tenant_display_name"]
    != "PLAB-CA-004 - Require MFA for Azure management"
):
    fail("CA-004 display name changed")

if (
    ca004["target_resource_display_name"]
    != "Microsoft Admin Portals"
):
    fail("CA-004 current target is incorrect")

if ca004["current_mode"] != "report-only":
    fail("CA-004 is not report-only")

if ca004["enabled"] is not False:
    fail("CA-004 is incorrectly marked enforced")


metadata = ca004["target_resource_correction"]

if (
    metadata["initially_selected_resource"]
    != "Windows Azure Active Directory"
):
    fail("initial CA-004 resource history changed")

if (
    metadata["original_repository_claim"]
    != "Windows Azure Service Management API"
):
    fail("original repository claim history changed")

if metadata["corrected_resource"] != "Microsoft Admin Portals":
    fail("corrected CA-004 target changed")

if metadata["policy_remained_report_only"] is not True:
    fail("CA-004 report-only preservation missing")


current = config["current_state"]

if current["conditional_access_policy_count"] != 4:
    fail("current policy count changed")

if current["report_only_policy_count"] != 4:
    fail("all four policies must remain report-only")

if current["enabled_conditional_access_policy_count"] != 0:
    fail("Conditional Access enforcement unexpectedly present")

if current["security_defaults_enabled"] is not True:
    fail("Security Defaults is no longer enabled")


summary = config["report_only_target_correction"]

if summary["completed"] is not True:
    fail("correction not marked complete")

if summary["policy_id"] != "CA-004":
    fail("unexpected corrected policy")

if summary["policy_modification_count"] != 1:
    fail("correction must contain exactly one tenant modification")

if summary["corrected_resource"] != "Microsoft Admin Portals":
    fail("summary correction target invalid")

if summary["policy_remained_report_only"] is not True:
    fail("summary says CA-004 left report-only")

if summary["security_defaults_remained_enabled"] is not True:
    fail("Security Defaults preservation missing")

if summary["total_feature6_tenant_writes_through_6B_R1"] != 5:
    fail("unexpected cumulative Feature 6 write count")


hist_items = {
    item["id"]: item
    for item in historical["created_policies"]
}

hist_ca004 = hist_items["CA-004"]

if hist_ca004["target"] != "Windows Azure Active Directory":
    fail("historical initial CA-004 target is inaccurate")

hist_corr = historical["historical_correction"]

if (
    hist_corr["actual_initial_tenant_selection"]
    != "Windows Azure Active Directory"
):
    fail("historical tenant selection changed")

if (
    hist_corr["original_repository_claim"]
    != "Windows Azure Service Management API"
):
    fail("original repository claim changed")

if hist_corr["original_repository_claim_was_inaccurate"] is not True:
    fail("historical repository inaccuracy not acknowledged")


if correction["feature"] != "6":
    fail("unexpected correction evidence feature")

if correction["phase"] != "6B-R1":
    fail("unexpected correction evidence phase")


before = correction["before_correction"]
change = correction["correction"]
after = correction["after_correction"]

if before["target_resource"] != "Windows Azure Active Directory":
    fail("before-correction target invalid")

if before["mode"] != "report-only":
    fail("before-correction policy mode invalid")

if before["enforced"] is not False:
    fail("before-correction enforcement state invalid")

if (
    change["target_resource_removed"]
    != "Windows Azure Active Directory"
):
    fail("wrong resource recorded as removed")

if change["target_resource_added"] != "Microsoft Admin Portals":
    fail("wrong resource recorded as added")

if change["tenant_write_count"] != 1:
    fail("correction must record exactly one tenant write")

if after["target_resource"] != "Microsoft Admin Portals":
    fail("after-correction target invalid")

if after["mode"] != "report-only":
    fail("after-correction policy mode invalid")

if after["enforced"] is not False:
    fail("after-correction enforcement state invalid")


baseline = correction["baseline_state"]

if baseline["conditional_access_policy_count"] != 4:
    fail("baseline policy count changed")

if baseline["report_only_policy_count"] != 4:
    fail("baseline report-only count changed")

if baseline["enabled_policy_count"] != 0:
    fail("baseline unexpectedly enforced")

if baseline["security_defaults_enabled"] is not True:
    fail("Security Defaults disabled")

if baseline["ca_pilot_group_member_count"] != 0:
    fail("CA pilot group changed")

if correction["recovery"]["additional_tenant_writes"] != 0:
    fail("recovery unexpectedly performed another tenant write")

if any(correction["protected_state"].values()):
    fail("protected tenant state changed")

if any(correction["privacy"].values()):
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
    ("historical evidence", historical_raw),
    ("correction evidence", correction_raw),
):
    if email.search(raw):
        fail(f"complete UPN/email detected in {name}")

    if guid.search(raw):
        fail(f"GUID detected in {name}")


print("PASS: Feature 6B-R1 correction contract valid.")
print("PASS: actual initial target history preserved.")
print("PASS: current CA-004 target = Microsoft Admin Portals.")
print("PASS: CA-004 remains report-only.")
print("PASS: four policies remain report-only.")
print("PASS: zero policies are enforced.")
print("PASS: Security Defaults remains enabled.")
print("PASS: exactly one correction write recorded.")
print("PASS: recovery additional writes = 0.")
print("PASS: no unrelated tenant state changed.")
print("PASS: no tenant identifier or secret detected.")
