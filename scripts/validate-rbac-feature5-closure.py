#!/usr/bin/env python3

import json
import re
import sys
from pathlib import Path


def fail(message: str) -> None:
    raise SystemExit(f"FAIL: {message}")


if len(sys.argv) != 5:
    fail(
        "usage: validate-rbac-feature5-closure.py "
        "<rbac.json> "
        "<role-evidence.json> "
        "<emergency-evidence.json> "
        "<closure-evidence.json>"
    )


rbac_path = Path(sys.argv[1])
role_path = Path(sys.argv[2])
emergency_path = Path(sys.argv[3])
closure_path = Path(sys.argv[4])

for path in (
    rbac_path,
    role_path,
    emergency_path,
    closure_path,
):
    if not path.is_file():
        fail(f"missing file: {path}")


rbac_raw = rbac_path.read_text()
role_raw = role_path.read_text()
emergency_raw = emergency_path.read_text()
closure_raw = closure_path.read_text()

rbac = json.loads(rbac_raw)
role = json.loads(role_raw)
emergency_evidence = json.loads(emergency_raw)
closure = json.loads(closure_raw)


# -------------------------------------------------
# Current dedicated privileged administrator
# -------------------------------------------------

principal = rbac["principals"]["privileged_admin_01"]

if principal["logical_id"] != "PRIVILEGED_ADMIN_01":
    fail("unexpected privileged-admin logical ID")

if (
    principal["provisioning_state"]
    != "created-privileged-auth-ready"
):
    fail("privileged administrator not operational")

if (
    principal["current_directory_role"]
    != "Privileged Role Administrator"
):
    fail("privileged administrator role changed")

if (
    principal["current_role_assignment_model"]
    != "active-static-interim"
):
    fail("unexpected privileged role assignment model")

if principal["current_role_scope"] != "tenant":
    fail("unexpected privileged role scope")

if principal["pim_configured"] is not False:
    fail("PIM must remain deferred to Feature 7")

if (
    principal["strong_authentication_state"]
    != "validated-authenticator-and-device-bound-passkey"
):
    fail("privileged authentication state invalid")


role_post = role["post_assignment_state"]

if role_post["directory_role_assignment_count"] != 1:
    fail("privileged administrator must have exactly one role")

if (
    role_post["expected_directory_role"]
    != "Privileged Role Administrator"
):
    fail("privileged role evidence changed")

if role_post["global_administrator_assigned_to_principal"] is not False:
    fail("privileged administrator must not receive Global Administrator")

if role_post["group_membership_count"] != 0:
    fail("privileged administrator must remain outside groups")

if role_post["license_count"] != 0:
    fail("privileged administrator must remain unlicensed")

if role_post["microsoft_authenticator_present"] is not True:
    fail("Microsoft Authenticator missing")

if role_post["device_bound_passkey_present"] is not True:
    fail("device-bound passkey missing")

if role_post["global_administrator_assignment_count"] != 1:
    fail("Global Administrator baseline changed")

if role_post["security_defaults_enabled"] is not True:
    fail("Security Defaults changed")


functional = role["functional_validation"]

if functional["fresh_passkey_sign_in_successful"] is not True:
    fail("fresh passkey sign-in not validated")

if functional["roles_and_administrators_access_successful"] is not True:
    fail("privileged role management access not validated")

if (
    functional[
        "privileged_role_administrator_assignments_read_successful"
    ]
    is not True
):
    fail("PRA assignment read validation missing")

if (
    functional[
        "administrative_writes_performed_during_functional_test"
    ]
    != 0
):
    fail("privilege functional test performed a write")


# -------------------------------------------------
# Emergency access
# -------------------------------------------------

emergency = rbac["principals"]["emergency_access"]

expected_emergency_ids = {
    "EMERGENCY_ADMIN_01",
    "EMERGENCY_ADMIN_02",
}

if set(emergency["logical_ids"]) != expected_emergency_ids:
    fail("emergency identity contract changed")

if (
    emergency["current_operational_state"]
    != "created-disabled-unlicensed-unprivileged-auth-deferred"
):
    fail("emergency state is not the approved deferred state")

if emergency["current_account_enabled_count"] != 0:
    fail("emergency identities unexpectedly enabled")

if emergency["current_directory_role_assignment_count"] != 0:
    fail("emergency identities unexpectedly privileged")

if emergency["current_group_membership_count"] != 0:
    fail("emergency identities unexpectedly grouped")

if emergency["current_license_count"] != 0:
    fail("emergency identities unexpectedly licensed")

if emergency["operationalization_status"] != "deferred":
    fail("emergency operationalization must remain deferred")

if (
    emergency["weaker_authentication_substitution_allowed"]
    is not False
):
    fail("weak emergency authentication substitution allowed")

if emergency["bootstrap_reduction_blocked"] is not True:
    fail("bootstrap reduction must remain blocked")


expected_future_options = {
    "physical-fido2-security-key",
    "device-bound-passkey",
}

if set(
    emergency["future_authentication_options"]
) != expected_future_options:
    fail("future emergency authentication options changed")

if (
    emergency[
        "future_authentication_selected_for_current_project"
    ]
    is not None
):
    fail("future emergency authentication option selected")

if (
    emergency[
        "future_authentication_implemented_in_current_project"
    ]
    is not False
):
    fail("future emergency authentication option implemented")


decision = emergency_evidence["decision"]

if decision["emergency_operationalization_completed"] is not False:
    fail("emergency recovery incorrectly marked operational")

if decision["emergency_operationalization_deferred"] is not True:
    fail("emergency deferral missing")

if set(
    decision["possible_future_implementations"]
) != expected_future_options:
    fail("future emergency options missing from evidence")

if decision["selected_for_current_project"] is not None:
    fail("future option selected in current project")

if decision["implemented_in_current_project"] is not False:
    fail("future option incorrectly marked implemented")

if decision["future_options_only"] is not True:
    fail("future emergency methods must remain documentation-only")


# -------------------------------------------------
# Closure evidence
# -------------------------------------------------

if closure["feature"] != "5":
    fail("unexpected closure feature")

if closure["phase"] != "5E":
    fail("unexpected closure phase")

status = closure["feature_status"]

if status["complete"] is not True:
    fail("Feature 5 not marked complete")

if (
    status["completion_class"]
    != "complete-with-explicit-emergency-operationalization-deferral"
):
    fail("Feature 5 completion class changed")


closure_admin = closure["privileged_administrator"]

if closure_admin["operational"] is not True:
    fail("closure does not mark privileged administrator operational")

if closure_admin["directory_role_assignment_count"] != 1:
    fail("closure privileged role count invalid")

if (
    closure_admin["directory_role"]
    != "Privileged Role Administrator"
):
    fail("closure privileged role invalid")

if closure_admin["role_scope"] != "tenant":
    fail("closure privileged role scope invalid")

if closure_admin["assignment_model"] != "active-static-interim":
    fail("closure assignment model invalid")

if closure_admin["pim_configured"] is not False:
    fail("closure incorrectly claims PIM configured")

if closure_admin["group_membership_count"] != 0:
    fail("closure privileged group count invalid")

if closure_admin["license_count"] != 0:
    fail("closure privileged license count invalid")

if closure_admin["global_administrator_assigned"] is not False:
    fail("closure incorrectly assigns Global Administrator")


tenant = closure["tenant_protected_baseline"]

if tenant["global_administrator_assignment_count"] != 1:
    fail("closure Global Administrator baseline invalid")

if tenant["security_defaults_enabled"] is not True:
    fail("closure Security Defaults state invalid")


closure_emergency = closure["emergency_access"]

if closure_emergency["identity_count"] != 2:
    fail("closure emergency identity count invalid")

if closure_emergency["enabled_identity_count"] != 0:
    fail("closure emergency identities unexpectedly enabled")

if closure_emergency["directory_role_assignment_count"] != 0:
    fail("closure emergency role count invalid")

if closure_emergency["group_membership_count"] != 0:
    fail("closure emergency group count invalid")

if closure_emergency["license_count"] != 0:
    fail("closure emergency license count invalid")

if closure_emergency["live_recovery_path_operational"] is not False:
    fail("closure falsely claims live emergency recovery")

if closure_emergency["governance_defined"] is not True:
    fail("closure emergency governance missing")

if closure_emergency["operationalization_status"] != "deferred":
    fail("closure emergency deferral state invalid")

if set(
    closure_emergency[
        "possible_future_authentication_options"
    ]
) != expected_future_options:
    fail("closure future emergency options invalid")

if closure_emergency["future_authentication_option_selected"] is not None:
    fail("closure future emergency option selected")

if (
    closure_emergency[
        "future_authentication_option_implemented"
    ]
    is not False
):
    fail("closure future emergency option implemented")


bootstrap = closure["bootstrap_administrator"]

if bootstrap["global_administrator_retained"] is not True:
    fail("bootstrap Global Administrator not retained")

if bootstrap["privilege_reduction_permitted"] is not False:
    fail("bootstrap reduction prematurely permitted")

if (
    bootstrap[
        "reduction_blocked_by_missing_operational_emergency_path"
    ]
    is not True
):
    fail("bootstrap reduction safety dependency missing")


boundaries = closure["feature_boundaries"]

if boundaries["conditional_access_owner_feature"] != 6:
    fail("Conditional Access ownership changed")

if boundaries["pim_owner_feature"] != 7:
    fail("PIM ownership changed")

if boundaries["identity_protection_owner_feature"] != 7:
    fail("Identity Protection ownership changed")

if (
    boundaries[
        "emergency_phishing_resistant_authentication_implemented"
    ]
    is not False
):
    fail("closure falsely claims emergency phishing-resistant auth")

if boundaries["bootstrap_reduction_implemented"] is not False:
    fail("closure falsely claims bootstrap reduction")


if any(closure["closure_activity"].values()):
    fail("Feature 5 closure unexpectedly performed tenant changes")

if any(closure["privacy"].values()):
    fail("Feature 5 closure privacy violation")


# -------------------------------------------------
# Privacy
# -------------------------------------------------

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
    ("rbac", rbac_raw),
    ("role evidence", role_raw),
    ("emergency evidence", emergency_raw),
    ("closure evidence", closure_raw),
):
    if email_pattern.search(raw):
        fail(f"complete UPN/email detected in {name}")

    if guid_pattern.search(raw):
        fail(f"GUID detected in {name}")


print("PASS: Feature 5 closure contract valid.")
print("PASS: privileged administrator operational.")
print("PASS: role = Privileged Role Administrator.")
print("PASS: privileged role count = 1.")
print("PASS: privileged groups = 0.")
print("PASS: privileged licenses = 0.")
print("PASS: strong authentication validated.")
print("PASS: Global Administrator not assigned to privileged admin.")
print("PASS: Global Administrator baseline = 1.")
print("PASS: Security Defaults enabled.")
print("PASS: emergency identities = 2.")
print("PASS: emergency identities remain disabled.")
print("PASS: emergency roles/groups/licenses remain zero.")
print("PASS: emergency recovery path explicitly deferred.")
print("PASS: FIDO2 and passkey remain future-only.")
print("PASS: bootstrap Global Administrator retained.")
print("PASS: bootstrap reduction remains blocked.")
print("PASS: Conditional Access remains Feature 6.")
print("PASS: PIM and Identity Protection remain Feature 7.")
print("PASS: closure tenant writes = 0.")
print("PASS: no tenant identifier or secret detected.")
