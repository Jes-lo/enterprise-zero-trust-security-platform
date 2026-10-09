#!/usr/bin/env python3

import json
import re
import sys
from pathlib import Path


def fail(message: str) -> None:
    raise SystemExit(f"FAIL: {message}")


if len(sys.argv) != 3:
    fail(
        "usage: validate-conditional-access-baseline.py "
        "<config.json> <evidence.json>"
    )


config_path = Path(sys.argv[1])
evidence_path = Path(sys.argv[2])

for path in (config_path, evidence_path):
    if not path.is_file():
        fail(f"missing file: {path}")


config_raw = config_path.read_text()
evidence_raw = evidence_path.read_text()

config = json.loads(config_raw)
evidence = json.loads(evidence_raw)


if config["feature"] != "6":
    fail("unexpected feature")

if config["phase"] not in {"6A", "6B"}:
    fail("unexpected phase")

phase = config["phase"]


current = config["current_state"]

if current["security_defaults_enabled"] is not True:
    fail("Security Defaults baseline must be enabled")

expected_current_policy_count = 0 if phase == "6A" else 4

if (
    current["conditional_access_policy_count"]
    != expected_current_policy_count
):
    fail("unexpected current CA policy count for lifecycle phase")

if current["conditional_access_capability_available"] is not True:
    fail("Conditional Access capability missing")

if (
    current["license_basis"]
    != "Microsoft 365 Business Premium / Microsoft Entra ID P1"
):
    fail("unexpected Conditional Access license basis")

if current["ca_pilot_group"] != "PLAB-CA-Pilot":
    fail("unexpected CA pilot group")

if current["ca_pilot_group_member_count"] != 0:
    fail("CA pilot group must remain empty in Feature 6A")

if current["bootstrap_global_administrator_retained"] is not True:
    fail("bootstrap Global Administrator must remain retained")

if current["bootstrap_mfa_capable_method_present"] is not True:
    fail("bootstrap MFA-capable method not validated")

if current["privileged_admin_role"] != "Privileged Role Administrator":
    fail("privileged administrator role changed")

if current["privileged_admin_group_membership_count"] != 0:
    fail("privileged administrator unexpectedly grouped")

if current["privileged_admin_license_count"] != 0:
    fail("privileged administrator unexpectedly licensed")

if current["emergency_access_operational"] is not False:
    fail("emergency access incorrectly marked operational")


migration = config["migration_principles"]

required_true = (
    "report_only_first",
    "security_defaults_preserved_during_design",
    "security_defaults_preserved_during_initial_report_only_staging",
    "security_defaults_cutover_requires_separate_explicit_gate",
    "replacement_baseline_must_be_ready_before_security_defaults_disable",
    "enable_replacement_baseline_immediately_after_security_defaults_disable",
    "lockout_prevention_required",
    "what_if_validation_required",
    "sign_in_log_validation_required",
)

for key in required_true:
    if migration[key] is not True:
        fail(f"required migration control missing: {key}")

if (
    migration[
        "conditional_access_enforcement_while_security_defaults_enabled"
    ]
    is not False
):
    fail("CA enforcement incorrectly allowed with Security Defaults")

if migration["bootstrap_reduction_allowed"] is not False:
    fail("bootstrap reduction prematurely allowed")


policies = config["planned_policies"]

if len(policies) != 4:
    fail("exactly four baseline policies must be planned")

expected_ids = {
    "CA-001",
    "CA-002",
    "CA-003",
    "CA-004",
}

if {policy["id"] for policy in policies} != expected_ids:
    fail("planned Conditional Access policy IDs changed")

for policy in policies:
    if policy["planned_initial_mode"] != "report-only":
        fail(f"{policy['id']} must begin report-only")

    if phase == "6A":
        if policy["created"] is not False:
            fail(f"{policy['id']} incorrectly marked created")

    elif phase == "6B":
        if policy["created"] is not True:
            fail(f"{policy['id']} not recorded as created")

        if policy.get("current_mode") != "report-only":
            fail(f"{policy['id']} not recorded as report-only")

        if not policy.get("tenant_display_name"):
            fail(f"{policy['id']} tenant display name missing")

    if policy["enabled"] is not False:
        fail(f"{policy['id']} incorrectly marked enabled")


by_id = {
    policy["id"]: policy
    for policy in policies
}

if (
    by_id["CA-001"]["grant_control"]
    != "require-multifactor-authentication"
):
    fail("CA-001 grant control changed")

if (
    by_id["CA-002"]["grant_control"]
    != "require-multifactor-authentication"
):
    fail("CA-002 grant control changed")

if set(by_id["CA-002"]["target_directory_roles"]) != {
    "Global Administrator",
    "Privileged Role Administrator",
}:
    fail("CA-002 privileged role scope changed")

if by_id["CA-003"]["grant_control"] != "block":
    fail("CA-003 must block legacy authentication")

if (
    by_id["CA-003"]["client_app_condition"]
    != "legacy-authentication-clients"
):
    fail("CA-003 legacy-auth condition changed")

if (
    by_id["CA-004"]["target_resource"]
    != "microsoft-azure-management"
):
    fail("CA-004 management target changed")


pilot = config["pilot_strategy"]

if pilot["pilot_group"] != "PLAB-CA-Pilot":
    fail("pilot group changed")

if pilot["current_member_count"] != 0:
    fail("pilot group no longer empty")

if pilot["planned_first_pilot_principal"] != "EMPLOYEE_01":
    fail("planned first pilot principal changed")

if pilot["pilot_membership_change_authorized"] is not False:
    fail("pilot membership change prematurely authorized")

if pilot["report_only_policy_creation_authorized"] is not False:
    fail("report-only policy creation prematurely authorized")

if pilot["policy_enforcement_authorized"] is not False:
    fail("CA enforcement prematurely authorized")


boundaries = config["feature_boundaries"]

if boundaries["pim_owner_feature"] != 7:
    fail("PIM ownership changed")

if boundaries["identity_protection_owner_feature"] != 7:
    fail("Identity Protection ownership changed")

if boundaries["risk_based_conditional_access_owner_feature"] != 7:
    fail("risk-based CA ownership changed")

if boundaries["device_compliance_enforcement_owner_feature"] != 9:
    fail("device compliance ownership changed")

if boundaries["endpoint_defender_owner_feature"] != 10:
    fail("Defender ownership changed")


if any(config["authorization"].values()):
    fail("Feature 6A contains unauthorized write permission")


if evidence["feature"] != "6":
    fail("unexpected evidence feature")

if evidence["phase"] != "6A":
    fail("unexpected evidence phase")


tenant = evidence["tenant_state"]

if tenant["security_defaults_enabled"] is not True:
    fail("evidence Security Defaults state invalid")

if tenant["conditional_access_capability_available"] is not True:
    fail("evidence CA capability invalid")

if tenant["conditional_access_policy_count"] != 0:
    fail("evidence CA policy count invalid")

if tenant["ca_pilot_group_member_count"] != 0:
    fail("evidence CA pilot membership count invalid")

if tenant["bootstrap_mfa_capable_method_present"] is not True:
    fail("evidence bootstrap MFA readiness invalid")


priv = evidence["privileged_administration_state"]

if priv["dedicated_privileged_admin_role"] != "Privileged Role Administrator":
    fail("evidence privileged-admin role changed")

if priv["dedicated_privileged_admin_role_count"] != 1:
    fail("evidence privileged-admin role count changed")

if priv["dedicated_privileged_admin_group_count"] != 0:
    fail("evidence privileged-admin groups changed")

if priv["dedicated_privileged_admin_license_count"] != 0:
    fail("evidence privileged-admin licenses changed")

if priv["dedicated_privileged_admin_global_administrator"] is not False:
    fail("evidence incorrectly grants Global Administrator")

if priv["global_administrator_assignment_count"] != 1:
    fail("Global Administrator baseline changed")

if priv["bootstrap_global_administrator_retained"] is not True:
    fail("bootstrap retention evidence invalid")


emergency = evidence["emergency_access_state"]

if emergency["identity_count"] != 2:
    fail("unexpected emergency identity count")

if emergency["enabled_identity_count"] != 0:
    fail("emergency identities unexpectedly enabled")

if emergency["directory_role_assignment_count"] != 0:
    fail("emergency identities unexpectedly privileged")

if emergency["group_membership_count"] != 0:
    fail("emergency identities unexpectedly grouped")

if emergency["license_count"] != 0:
    fail("emergency identities unexpectedly licensed")

if emergency["live_recovery_path_operational"] is not False:
    fail("evidence falsely claims emergency recovery")


activity = evidence["feature6a_activity"]

integer_zero_keys = (
    "tenant_writes",
    "conditional_access_policies_created",
    "conditional_access_policies_modified",
    "conditional_access_policies_enabled",
    "group_memberships_modified",
    "roles_modified",
    "authentication_methods_modified",
    "licenses_modified",
)

for key in integer_zero_keys:
    if activity[key] != 0:
        fail(f"unexpected Feature 6A tenant write: {key}")

if activity["security_defaults_modified"] is not False:
    fail("Security Defaults modified during Feature 6A")

if any(evidence["privacy"].values()):
    fail("privacy control violation")


email_pattern = re.compile(
    r"[A-Za-z0-9._%+-]+@"
    r"[A-Za-z0-9.-]+\.[A-Za-z]{2,}"
)

guid_pattern = re.compile(
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
    if email_pattern.search(raw):
        fail(f"complete UPN/email detected in {name}")

    if guid_pattern.search(raw):
        fail(f"GUID detected in {name}")


print("PASS: Feature 6A Conditional Access baseline valid.")
print("PASS: Security Defaults remains enabled.")
print("PASS: current Conditional Access policies = 0.")
print("PASS: Conditional Access capability available.")
print("PASS: PLAB-CA-Pilot remains empty.")
print("PASS: bootstrap MFA-capable method validated.")
print("PASS: privileged administration baseline preserved.")
print("PASS: emergency access remains deferred.")
print("PASS: four baseline CA policies are planned.")
print("PASS: all planned policies begin report-only.")
print("PASS: no Conditional Access policy has been created.")
print("PASS: no policy enforcement is authorized.")
print("PASS: Security Defaults cutover is not authorized.")
print("PASS: PIM / Identity Protection remain Feature 7.")
print("PASS: Feature 6A tenant writes = 0.")
print("PASS: no tenant identifier or secret detected.")
