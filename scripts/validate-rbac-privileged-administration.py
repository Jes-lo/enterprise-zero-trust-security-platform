#!/usr/bin/env python3

import json
import re
import sys
from pathlib import Path


def fail(message: str) -> None:
    raise SystemExit(f"FAIL: {message}")


if len(sys.argv) != 2:
    fail(
        "usage: validate-rbac-privileged-administration.py "
        "<config.json>"
    )

path = Path(sys.argv[1])

if not path.is_file():
    fail("configuration file does not exist")

raw = path.read_text()
data = json.loads(raw)

if data.get("schema_version") != "1.0":
    fail("unexpected schema_version")

if data.get("feature") != "5":
    fail("unexpected feature")

if data.get("phase") != "5B":
    fail("unexpected phase")

if data.get("mode") != "design-only":
    fail("Feature 5B must remain design-only")

baseline = data["baseline"]

if baseline["active_role_assignment_count"] != 1:
    fail("baseline assignment count changed unexpectedly")

if baseline["active_role_types"] != {
    "Global Administrator": 1
}:
    fail("baseline role state changed unexpectedly")

if (
    baseline["unknown_or_custom_role_assignment_count"]
    != 0
):
    fail("baseline contains unexpected custom roles")

boundaries = data["feature_boundaries"]

if boundaries["conditional_access_owner_feature"] != 6:
    fail("Conditional Access ownership must remain Feature 6")

if boundaries["pim_owner_feature"] != 7:
    fail("PIM ownership must remain Feature 7")

if boundaries["identity_protection_owner_feature"] != 7:
    fail("Identity Protection ownership must remain Feature 7")

if boundaries["security_defaults_preserved"] is not True:
    fail("Security Defaults must remain preserved")

for key in (
    "conditional_access_changes_allowed",
    "pim_changes_allowed",
    "identity_protection_changes_allowed",
    "tenant_writes_allowed_in_phase_5B",
):
    if boundaries[key] is not False:
        fail(f"{key} must remain false")

principals = data["principals"]

bootstrap = principals["bootstrap_admin"]

if bootstrap["current_role"] != "Global Administrator":
    fail("bootstrap current role changed unexpectedly")

if bootstrap["state"] != "transitional":
    fail("bootstrap must remain transitional")

if bootstrap["remove_or_reduce_role_now"] is not False:
    fail("bootstrap privilege reduction is not authorized")

privileged = principals["privileged_admin_01"]

if privileged["logical_id"] != "PRIVILEGED_ADMIN_01":
    fail("unexpected privileged-admin logical ID")

if privileged["routine_workforce_identity"] is not False:
    fail("privileged admin cannot be a routine workforce identity")

if (
    privileged["initial_feature5_role"]
    != "Privileged Role Administrator"
):
    fail(
        "initial Feature 5 role must be "
        "Privileged Role Administrator"
    )

if privileged["initial_feature5_role"] == "Global Administrator":
    fail("PRIVILEGED_ADMIN_01 must not default to Global Administrator")

if privileged["assignment_mode"] != "active-static-interim":
    fail("unexpected interim assignment mode")

if privileged["pim_conversion_owner_feature"] != 7:
    fail("PIM conversion must remain Feature 7")

if privileged["requires_explicit_pre_write_gate"] is not True:
    fail("privileged account requires an explicit write gate")

if privileged["requires_strong_authentication_before_use"] is not True:
    fail("strong authentication requirement missing")

emergency = principals["emergency_access"]

if emergency["target_count"] != 2:
    fail("target emergency-access account count must be two")

if len(emergency["logical_ids"]) != 2:
    fail("exactly two emergency logical IDs are required")

if emergency["target_role"] != "Global Administrator":
    fail("emergency target role must remain Global Administrator")

if emergency["routine_use"] is not False:
    fail("emergency identities cannot be routine-use identities")

if emergency["live_changes_in_phase_5B"] is not False:
    fail("Feature 5B cannot modify emergency accounts")

if emergency["requires_separate_explicit_gate"] is not True:
    fail("emergency changes require a separate gate")

role_strategy = data["role_strategy"]

if role_strategy["least_privilege_required"] is not True:
    fail("least privilege must be enabled")

if role_strategy["global_administrator_for_routine_admin"] is not False:
    fail("Global Administrator cannot be routine admin target")

if (
    role_strategy["privileged_role_administrator_initial_assignment"]
    is not True
):
    fail("initial PRA strategy missing")

if (
    role_strategy["future_service_roles_added_only_for_documented_tasks"]
    is not True
):
    fail("future service roles require documented tasks")

authentication = data["authentication"]

if (
    authentication["privileged_accounts_require_strong_authentication"]
    is not True
):
    fail("strong authentication must be required")

if authentication["phishing_resistant_method_preferred"] is not True:
    fail("phishing-resistant method preference missing")

if authentication["password_only_privileged_operation_allowed"] is not False:
    fail("password-only privileged operation cannot be allowed")

if authentication["shared_credentials_allowed"] is not False:
    fail("shared privileged credentials cannot be allowed")

gate = data["bootstrap_reduction_gate"]

if gate["all_conditions_required"] is not True:
    fail("bootstrap reduction gate must require all conditions")

if len(gate["conditions"]) < 6:
    fail("bootstrap reduction gate is incomplete")

evidence = data["evidence_policy"]

if evidence["raw_principal_exports_tracked"] is not False:
    fail("raw principal exports cannot be tracked")

if evidence["tenant_specific_ids_tracked"] is not False:
    fail("tenant-specific IDs cannot be tracked")

if evidence["tenant_domain_tracked"] is not False:
    fail("tenant domain cannot be tracked")

if evidence["complete_upns_tracked"] is not False:
    fail("complete UPNs cannot be tracked")

if evidence["sanitized_evidence_only"] is not True:
    fail("tracked evidence must remain sanitized")

next_phase = data["next_live_phase"]

if next_phase["phase"] != "5C":
    fail("next live phase must be 5C")

if next_phase["authorized_by_this_file"] is not False:
    fail("Feature 5B must not authorize live writes")

if next_phase["explicit_user_gate_required"] is not True:
    fail("Feature 5C requires explicit user approval")

email_pattern = re.compile(
    r"[A-Za-z0-9._%+-]+@"
    r"[A-Za-z0-9.-]+\.[A-Za-z]{2,}"
)

guid_pattern = re.compile(
    r"\b"
    r"[0-9a-fA-F]{8}-"
    r"[0-9a-fA-F]{4}-"
    r"[0-9a-fA-F]{4}-"
    r"[0-9a-fA-F]{4}-"
    r"[0-9a-fA-F]{12}"
    r"\b"
)

if email_pattern.search(raw):
    fail("complete email/UPN detected")

if guid_pattern.search(raw):
    fail("GUID detected")

print("PASS: Feature 5B RBAC contract valid.")
print("PASS: baseline remains one Global Administrator assignment.")
print("PASS: PRIVILEGED_ADMIN_01 initial role is Privileged Role Administrator.")
print("PASS: bootstrap privilege reduction remains blocked.")
print("PASS: two emergency-access identities are modeled but not modified.")
print("PASS: Security Defaults remains preserved.")
print("PASS: Conditional Access remains Feature 6.")
print("PASS: PIM and Identity Protection remain Feature 7.")
print("PASS: Feature 5B authorizes zero tenant writes.")
print("PASS: no UPN/email or GUID exists in the contract.")
