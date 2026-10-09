#!/usr/bin/env python3

import json
import re
import sys
from pathlib import Path


def fail(message: str) -> None:
    raise SystemExit(f"FAIL: {message}")


if len(sys.argv) != 3:
    fail(
        "usage: validate-conditional-access-feature6-closure.py "
        "<config.json> <closure-evidence.json>"
    )


config_path = Path(sys.argv[1])
evidence_path = Path(sys.argv[2])

config_raw = config_path.read_text()
evidence_raw = evidence_path.read_text()

config = json.loads(config_raw)
evidence = json.loads(evidence_raw)


if config["feature"] != "6":
    fail("unexpected feature")

if config["phase"] != "6D":
    fail("Feature 6 lifecycle is not closed at 6D")


current = config["current_state"]

if current["security_defaults_enabled"] is not True:
    fail("Security Defaults must remain enabled at Feature 6 closure")

if current["conditional_access_policy_count"] != 4:
    fail("Feature 6 closure requires exactly four CA policies")

if current["report_only_policy_count"] != 4:
    fail("all four policies must remain report-only")

if current["enabled_conditional_access_policy_count"] != 0:
    fail("Feature 6 closure must contain zero enforced CA policies")


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

for policy_id, policy in policies.items():
    if policy["created"] is not True:
        fail(f"{policy_id} is not created")

    if policy["current_mode"] != "report-only":
        fail(f"{policy_id} is not report-only")

    if policy["enabled"] is not False:
        fail(f"{policy_id} incorrectly recorded as enabled")


if (
    policies["CA-004"]["target_resource_display_name"]
    != "Microsoft Admin Portals"
):
    fail("CA-004 target changed")


evaluation = config["report_only_evaluation"]

if evaluation["completed"] is not True:
    fail("Feature 6C evaluation is not complete")

if evaluation["what_if_scenarios_passed"] != 5:
    fail("five What If validations are required")

if evaluation["real_sign_in_log_validation_passed"] is not True:
    fail("real sign-in report-only validation is required")

if evaluation["policy_logic_validated"] is not True:
    fail("policy logic was not validated")

if evaluation["enforcement_ready"] is not False:
    fail("Feature 6C incorrectly claims enforcement readiness")

if (
    evaluation["enforcement_blocker"]
    != "emergency-access-identities-remain-nonoperational"
):
    fail("Feature 6C enforcement blocker changed")


closure = config["feature6_closure"]

if closure["completed"] is not True:
    fail("Feature 6 closure not marked complete")

if (
    closure["closure_state"]
    != "validated-report-only-baseline-enforcement-deferred"
):
    fail("unexpected Feature 6 closure state")

if closure["tenant_configuration_writes"] != 0:
    fail("Feature 6D must perform zero tenant configuration writes")

if closure["conditional_access_policy_count"] != 4:
    fail("closure policy count changed")

if closure["report_only_policy_count"] != 4:
    fail("closure report-only count changed")

if closure["enabled_policy_count"] != 0:
    fail("closure unexpectedly records CA enforcement")

if closure["security_defaults_enabled"] is not True:
    fail("closure says Security Defaults disabled")

if closure["policy_logic_validated"] is not True:
    fail("closure does not preserve policy validation")

if closure["what_if_validation_completed"] is not True:
    fail("closure does not preserve What If validation")

if closure["real_sign_in_validation_completed"] is not True:
    fail("closure does not preserve sign-in validation")

if closure["emergency_exclusions_validated"] is not True:
    fail("closure does not preserve emergency exclusions")

if closure["current_ca004_target"] != "Microsoft Admin Portals":
    fail("closure CA-004 target changed")

if closure["enforcement_ready"] is not False:
    fail("closure falsely claims enforcement readiness")

if closure["enforcement_performed"] is not False:
    fail("closure falsely claims enforcement occurred")

if closure["policy_enforcement_authorized"] is not False:
    fail("closure prematurely authorizes policy enforcement")

if closure["security_defaults_cutover_authorized"] is not False:
    fail("closure prematurely authorizes Security Defaults cutover")

if (
    closure["enforcement_blocker"]
    != "emergency-access-identities-remain-nonoperational"
):
    fail("closure enforcement blocker changed")

if closure["emergency_access_operational"] is not False:
    fail("closure falsely claims emergency access is operational")

if closure["weaker_emergency_auth_fallback_permitted"] is not False:
    fail("closure permits weaker emergency authentication")

if closure["bootstrap_reduction_authorized"] is not False:
    fail("closure prematurely authorizes bootstrap reduction")

if closure["cumulative_feature6_tenant_writes"] != 5:
    fail("unexpected cumulative Feature 6 tenant-write count")

if closure["next_feature"] != "7":
    fail("unexpected next feature")

if (
    closure["next_feature_scope"]
    != "privileged-identity-management-and-identity-protection"
):
    fail("unexpected Feature 7 scope")


if any(config["authorization"].values()):
    fail("future tenant-write authorization leaked into config")


if evidence["feature"] != "6":
    fail("unexpected closure evidence feature")

if evidence["phase"] != "6D":
    fail("unexpected closure evidence phase")


evidence_closure = evidence["closure"]

if evidence_closure["completed"] is not True:
    fail("closure evidence not marked complete")

if (
    evidence_closure["state"]
    != "validated-report-only-baseline-enforcement-deferred"
):
    fail("closure evidence state changed")

if evidence_closure["tenant_configuration_writes"] != 0:
    fail("closure evidence records tenant configuration writes")


tenant = evidence["tenant_state"]

if tenant["security_defaults_enabled"] is not True:
    fail("closure evidence says Security Defaults disabled")

if tenant["conditional_access_policy_count"] != 4:
    fail("closure evidence policy count changed")

if tenant["report_only_policy_count"] != 4:
    fail("closure evidence report-only count changed")

if tenant["enabled_policy_count"] != 0:
    fail("closure evidence records enforcement")

if tenant["ca_pilot_group_member_count"] != 0:
    fail("closure evidence says CA pilot group changed")


controls = evidence["validated_controls"]

required_controls = (
    "ca001_broad_mfa_logic",
    "ca002_privileged_mfa_logic",
    "ca003_legacy_authentication_block_logic",
    "ca004_microsoft_admin_portals_logic",
    "what_if_validation",
    "real_sign_in_report_only_validation",
    "emergency_exclusions",
)

for key in required_controls:
    if controls[key] is not True:
        fail(f"validated control lost: {key}")


ca004 = evidence["ca004"]

if ca004["current_target"] != "Microsoft Admin Portals":
    fail("closure evidence CA-004 target changed")

if ca004["mode"] != "report-only":
    fail("closure evidence CA-004 mode changed")

if ca004["enforced"] is not False:
    fail("closure evidence falsely claims CA-004 enforcement")


decision = evidence["enforcement_decision"]

if decision["ready"] is not False:
    fail("closure evidence falsely claims readiness")

if decision["performed"] is not False:
    fail("closure evidence falsely claims enforcement")

if decision["authorized"] is not False:
    fail("closure evidence prematurely authorizes enforcement")

if decision["security_defaults_cutover_authorized"] is not False:
    fail("closure evidence prematurely authorizes cutover")

if (
    decision["reason"]
    != "emergency-access-identities-remain-nonoperational"
):
    fail("closure evidence blocker changed")


emergency = evidence["emergency_access"]

if emergency["identity_count"] != 2:
    fail("unexpected emergency identity count")

if emergency["operational"] is not False:
    fail("emergency access falsely recorded operational")

if emergency["independent_phishing_resistant_recovery_path"] is not False:
    fail("closure falsely records phishing-resistant recovery")

if emergency["weak_auth_fallback_permitted"] is not False:
    fail("closure permits weak emergency fallback")


if evidence["bootstrap"]["privilege_reduction_authorized"] is not False:
    fail("bootstrap reduction prematurely authorized")


writes = evidence["write_accounting"]

if writes["feature6a"] != 0:
    fail("Feature 6A write accounting changed")

if writes["feature6b_policy_creations"] != 4:
    fail("Feature 6B creation write accounting changed")

if writes["feature6b_r1_ca004_correction"] != 1:
    fail("Feature 6B-R1 correction accounting changed")

if writes["feature6c"] != 0:
    fail("Feature 6C write accounting changed")

if writes["feature6d"] != 0:
    fail("Feature 6D must contain zero tenant writes")

if writes["cumulative_feature6_tenant_writes"] != 5:
    fail("cumulative Feature 6 write accounting changed")


next_feature = evidence["next_feature"]

if next_feature["id"] != "7":
    fail("closure evidence next feature changed")

if (
    next_feature["scope"]
    != "privileged-identity-management-and-identity-protection"
):
    fail("closure evidence Feature 7 scope changed")


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
    ("closure evidence", evidence_raw),
):
    if email.search(raw):
        fail(f"complete UPN/email detected in {name}")

    if guid.search(raw):
        fail(f"tenant/object GUID detected in {name}")


print("PASS: Feature 6D closure contract valid.")
print("PASS: Feature 6 closed as validated Report-only baseline.")
print("PASS: four Conditional Access policies remain report-only.")
print("PASS: zero Conditional Access policies are enforced.")
print("PASS: Security Defaults remains enabled.")
print("PASS: Conditional Access policy logic remains validated.")
print("PASS: emergency access remains explicitly nonoperational.")
print("PASS: weaker emergency authentication remains forbidden.")
print("PASS: enforcement remains deferred and unauthorized.")
print("PASS: Security Defaults cutover remains unauthorized.")
print("PASS: Feature 6D tenant configuration writes = 0.")
print("PASS: cumulative Feature 6 tenant writes = 5.")
print("PASS: next lifecycle target = Feature 7.")
print("PASS: no tenant identifier or secret detected.")
