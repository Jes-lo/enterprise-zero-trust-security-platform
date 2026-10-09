#!/usr/bin/env python3

import json
import re
import sys
from pathlib import Path


def fail(message: str) -> None:
    raise SystemExit(f"FAIL: {message}")


if len(sys.argv) != 3:
    fail(
        "usage: validate-conditional-access-report-only-evaluation.py "
        "<config.json> <evaluation-evidence.json>"
    )


config_path = Path(sys.argv[1])
evidence_path = Path(sys.argv[2])

config_raw = config_path.read_text()
evidence_raw = evidence_path.read_text()

config = json.loads(config_raw)
evidence = json.loads(evidence_raw)


if config["feature"] != "6":
    fail("unexpected feature")

if config["phase"] != "6C":
    fail("Feature 6 lifecycle is not 6C")


current = config["current_state"]

if current["security_defaults_enabled"] is not True:
    fail("Security Defaults must remain enabled")

if current["conditional_access_policy_count"] != 4:
    fail("exactly four CA policies required")

if current["report_only_policy_count"] != 4:
    fail("all four policies must remain report-only")

if current["enabled_conditional_access_policy_count"] != 0:
    fail("no CA policy may be enforced")


policies = {
    item["id"]: item
    for item in config["planned_policies"]
}

expected_ids = {
    "CA-001",
    "CA-002",
    "CA-003",
    "CA-004",
}

if set(policies) != expected_ids:
    fail("unexpected policy set")

for policy_id, policy in policies.items():
    if policy["created"] is not True:
        fail(f"{policy_id} is not recorded as created")

    if policy["current_mode"] != "report-only":
        fail(f"{policy_id} is not report-only")

    if policy["enabled"] is not False:
        fail(f"{policy_id} is incorrectly marked enabled")


if (
    policies["CA-004"]["target_resource_display_name"]
    != "Microsoft Admin Portals"
):
    fail("CA-004 current target is incorrect")


evaluation = config["report_only_evaluation"]

if evaluation["completed"] is not True:
    fail("Feature 6C evaluation not marked complete")

if evaluation["tenant_configuration_writes"] != 0:
    fail("Feature 6C must not contain tenant configuration writes")

if evaluation["what_if_scenarios_passed"] != 5:
    fail("all five required What If scenarios must pass")

if evaluation["real_sign_in_log_validation_passed"] is not True:
    fail("real report-only sign-in validation missing")

if evaluation["security_defaults_remained_enabled"] is not True:
    fail("Security Defaults preservation missing")

if evaluation["conditional_access_policy_count"] != 4:
    fail("evaluation policy count changed")

if evaluation["report_only_policy_count"] != 4:
    fail("evaluation report-only count changed")

if evaluation["enabled_policy_count"] != 0:
    fail("evaluation unexpectedly records enforcement")

if evaluation["pilot_group_remained_empty"] is not True:
    fail("pilot group changed during Feature 6C")

if evaluation["policy_logic_validated"] is not True:
    fail("policy logic not validated")

if evaluation["enforcement_ready"] is not False:
    fail("Feature 6C must not claim enforcement readiness")

if (
    evaluation["enforcement_blocker"]
    != "emergency-access-identities-remain-nonoperational"
):
    fail("expected enforcement blocker missing")

if evaluation["policy_enforcement_authorized"] is not False:
    fail("policy enforcement prematurely authorized")

if evaluation["security_defaults_cutover_authorized"] is not False:
    fail("Security Defaults cutover prematurely authorized")


if evidence["feature"] != "6":
    fail("unexpected evidence feature")

if evidence["phase"] != "6C":
    fail("unexpected evidence phase")


tenant = evidence["tenant_state"]

if tenant["security_defaults_enabled"] is not True:
    fail("evidence says Security Defaults disabled")

if tenant["conditional_access_policy_count"] != 4:
    fail("evidence policy count changed")

if tenant["report_only_policy_count"] != 4:
    fail("evidence report-only count changed")

if tenant["enabled_policy_count"] != 0:
    fail("evidence records enforcement")

if tenant["ca_pilot_group_member_count"] != 0:
    fail("evidence says pilot group changed")

if tenant["tenant_configuration_writes"] != 0:
    fail("Feature 6C evidence contains tenant writes")


what_if = evidence["what_if"]

if what_if["scenario_count"] != 5:
    fail("unexpected What If scenario count")

scenarios = {
    item["id"]: item
    for item in what_if["scenarios"]
}

expected_scenarios = {
    "WIF-001": ["CA-001"],
    "WIF-002": ["CA-001", "CA-002"],
    "WIF-003": ["CA-001", "CA-002"],
    "WIF-004": ["CA-001", "CA-003"],
    "WIF-005": ["CA-001", "CA-004"],
}

if set(scenarios) != set(expected_scenarios):
    fail("unexpected What If scenario set")

for scenario_id, expected in expected_scenarios.items():
    scenario = scenarios[scenario_id]

    if scenario["validated"] is not True:
        fail(f"{scenario_id} is not validated")

    if scenario["expected_plab_applicable"] != expected:
        fail(f"{scenario_id} expected policy set changed")

    if scenario["device_platform"] != "Windows":
        fail(f"{scenario_id} device platform changed")


if scenarios["WIF-001"]["client_app"] != "Browser":
    fail("WIF-001 client app changed")

if scenarios["WIF-002"]["client_app"] != "Browser":
    fail("WIF-002 client app changed")

if scenarios["WIF-003"]["client_app"] != "Browser":
    fail("WIF-003 client app changed")

if scenarios["WIF-004"]["client_app"] != "Other clients":
    fail("WIF-004 no longer models legacy authentication")

if scenarios["WIF-004"]["expected_ca003_control"] != "block":
    fail("WIF-004 CA-003 control changed")

if scenarios["WIF-005"]["client_app"] != "Browser":
    fail("WIF-005 client app changed")


emergency = evidence["emergency_exclusion_validation"]

if emergency["method"] not in {
    "what-if",
    "policy-readback",
}:
    fail("unexpected emergency exclusion validation method")

if emergency["both_emergency_identities_excluded"] is not True:
    fail("emergency exclusions not validated")

if emergency["validated"] is not True:
    fail("emergency exclusion validation incomplete")


signin = evidence["real_sign_in_validation"]

if signin["identity"] != "BOOTSTRAP_ADMIN":
    fail("unexpected real sign-in identity alias")

if signin["ca001_applied"] is not True:
    fail("real sign-in did not validate CA-001")

if signin["ca002_applied"] is not True:
    fail("real sign-in did not validate CA-002")

if signin["ca003_applied"] is not False:
    fail("legacy-auth block unexpectedly applied to browser sign-in")

if signin["ca004_applied"] is not True:
    fail("real sign-in did not validate CA-004")

if signin["report_only_evaluation_confirmed"] is not True:
    fail("report-only sign-in evaluation not confirmed")


decision = evidence["decision"]

if decision["policy_logic_validated"] is not True:
    fail("evidence says policy logic is not validated")

if decision["safe_to_claim_enforcement"] is not False:
    fail("evidence falsely claims enforcement")

if decision["enforcement_ready"] is not False:
    fail("evidence falsely claims enforcement readiness")

if (
    decision["reason"]
    != "emergency-access-identities-remain-nonoperational"
):
    fail("evidence enforcement blocker changed")

if decision["policy_enforcement_authorized"] is not False:
    fail("evidence prematurely authorizes enforcement")

if decision["security_defaults_cutover_authorized"] is not False:
    fail("evidence prematurely authorizes Security Defaults cutover")


if any(evidence["privacy"].values()):
    fail("privacy control violation")


if any(config["authorization"].values()):
    fail("future tenant-write authorization leaked into config")


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
    ("evaluation evidence", evidence_raw),
):
    if email.search(raw):
        fail(f"complete UPN/email detected in {name}")

    if guid.search(raw):
        fail(f"tenant/object GUID detected in {name}")


print("PASS: Feature 6C report-only evaluation valid.")
print("PASS: five required What If scenarios validated.")
print("PASS: regular workforce MFA behavior validated.")
print("PASS: privileged-role MFA behavior validated.")
print("PASS: legacy authentication block behavior validated.")
print("PASS: Microsoft Admin Portals behavior validated.")
print("PASS: emergency exclusions validated.")
print("PASS: real report-only sign-in evidence validated.")
print("PASS: all four policies remain report-only.")
print("PASS: zero policies are enforced.")
print("PASS: Security Defaults remains enabled.")
print("PASS: Feature 6C tenant configuration writes = 0.")
print("PASS: enforcement remains blocked and unauthorized.")
print("PASS: no tenant identifier or secret detected.")
