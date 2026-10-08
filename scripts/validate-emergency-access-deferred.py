#!/usr/bin/env python3

import json
import re
import sys
from pathlib import Path


def fail(message: str) -> None:
    raise SystemExit(f"FAIL: {message}")


if len(sys.argv) != 3:
    fail(
        "usage: validate-emergency-access-deferred.py "
        "<rbac.json> <evidence.json>"
    )


rbac_path = Path(sys.argv[1])
evidence_path = Path(sys.argv[2])

for path in (rbac_path, evidence_path):
    if not path.is_file():
        fail(f"missing file: {path}")


rbac_raw = rbac_path.read_text()
evidence_raw = evidence_path.read_text()

rbac = json.loads(rbac_raw)
evidence = json.loads(evidence_raw)

emergency = rbac["principals"]["emergency_access"]

expected_ids = {
    "EMERGENCY_ADMIN_01",
    "EMERGENCY_ADMIN_02",
}

if set(emergency["logical_ids"]) != expected_ids:
    fail("unexpected emergency logical IDs")

if (
    emergency["current_operational_state"]
    != "created-disabled-unlicensed-unprivileged-auth-deferred"
):
    fail("emergency operationalization not explicitly deferred")

if emergency["current_account_enabled_count"] != 0:
    fail("emergency accounts must remain disabled")

if emergency["current_directory_role_assignment_count"] != 0:
    fail("deferred emergency accounts must remain unprivileged")

if emergency["current_group_membership_count"] != 0:
    fail("deferred emergency accounts must remain outside groups")

if emergency["current_license_count"] != 0:
    fail("deferred emergency accounts must remain unlicensed")

if (
    emergency["strong_authentication_state"]
    != "deferred-no-independent-phishing-resistant-credential"
):
    fail("unexpected deferred authentication state")

if emergency["operationalization_status"] != "deferred":
    fail("operationalization status must be deferred")

if (
    emergency["weaker_authentication_substitution_allowed"]
    is not False
):
    fail("weak emergency authentication substitution allowed")

if emergency["bootstrap_reduction_blocked"] is not True:
    fail("bootstrap reduction must remain blocked")

if emergency["target_role"] != "Global Administrator":
    fail("future emergency target role changed")

if (
    emergency["target_role_assignment_model"]
    != "permanent-active-emergency"
):
    fail("future emergency assignment model changed")

if (
    emergency["pim_target_state"]
    != "permanent-active-not-eligible"
):
    fail("future emergency PIM target changed")


expected_future_options = {
    "physical-fido2-security-key",
    "device-bound-passkey",
}

if set(emergency["future_authentication_options"]) != expected_future_options:
    fail("future emergency authentication options changed")

if (
    emergency["future_authentication_option_status"]
    != "documented-for-possible-future-implementation"
):
    fail("future authentication option status invalid")

if (
    emergency["future_authentication_selected_for_current_project"]
    is not None
):
    fail("future authentication option selected in current project")

if (
    emergency["future_authentication_implemented_in_current_project"]
    is not False
):
    fail("future authentication option implemented in current project")

if evidence["feature"] != "5":
    fail("unexpected evidence feature")

if evidence["phase"] != "5D2-D":
    fail("unexpected evidence phase")

decision = evidence["decision"]

if decision["emergency_operationalization_completed"] is not False:
    fail("evidence incorrectly claims operational emergency access")

if decision["emergency_operationalization_deferred"] is not True:
    fail("deferred decision missing")

if decision["physical_fido2_security_keys_available"] is not False:
    fail("physical FIDO2 availability incorrectly recorded")

if decision["windows_passkey_selected"] is not False:
    fail("Windows passkey incorrectly selected")

if decision["certificate_based_authentication_selected"] is not False:
    fail("CBA incorrectly selected")

if decision["weaker_authentication_substitution_selected"] is not False:
    fail("weak authentication incorrectly selected")


if set(
    decision["possible_future_implementations"]
) != expected_future_options:
    fail("future implementation options missing from evidence")

if decision["future_implementation_documented"] is not True:
    fail("future implementation documentation flag missing")

if decision["selected_for_current_project"] is not None:
    fail("future authentication selected in current project")

if decision["implemented_in_current_project"] is not False:
    fail("future authentication incorrectly marked implemented")

if decision["future_options_only"] is not True:
    fail("future authentication options are not documentation-only")

future_note = evidence["future_implementation_note"]

if future_note["status"] != "documented-not-implemented":
    fail("future implementation note status invalid")

if set(future_note["possible_methods"]) != expected_future_options:
    fail("future implementation note methods invalid")

if future_note["physical_fido2_key_applied"] is not False:
    fail("physical FIDO2 key incorrectly marked applied")

if future_note["device_bound_passkey_applied"] is not False:
    fail("device-bound passkey incorrectly marked applied")

if (
    future_note[
        "current_project_will_not_operationalize_these_methods"
    ]
    is not True
):
    fail("current-project non-implementation decision missing")

rationale = evidence["security_rationale"]

required_true = (
    "phishing_resistant_authentication_required_by_design",
)

for key in required_true:
    if rationale[key] is not True:
        fail(f"required security rationale missing: {key}")

required_false = (
    "routine_admin_authentication_reuse_allowed",
    "password_only_allowed",
    "totp_as_final_emergency_method_allowed",
    "sms_as_final_emergency_method_allowed",
    "emergency_global_administrator_without_validated_strong_auth_allowed",
)

for key in required_false:
    if rationale[key] is not False:
        fail(f"unsafe emergency option enabled: {key}")


current = evidence["current_tenant_state"]

if current["emergency_identity_count"] != 2:
    fail("unexpected emergency identity count")

if current["enabled_emergency_identity_count"] != 0:
    fail("emergency accounts unexpectedly enabled")

if current["emergency_directory_role_assignment_count"] != 0:
    fail("emergency roles unexpectedly assigned")

if current["emergency_group_membership_count"] != 0:
    fail("emergency group membership unexpectedly exists")

if current["emergency_license_count"] != 0:
    fail("emergency licenses unexpectedly assigned")

if current["emergency_strong_authentication_ready_count"] != 0:
    fail("emergency authentication readiness incorrectly claimed")

if current["global_administrator_assignment_count"] != 1:
    fail("Global Administrator baseline changed")

if current["security_defaults_enabled"] is not True:
    fail("Security Defaults unexpectedly disabled")


end = evidence["feature5_end_state"]

if end["dedicated_privileged_admin_operational"] is not True:
    fail("dedicated privileged administrator state invalid")

if end["dedicated_privileged_admin_role"] != "Privileged Role Administrator":
    fail("dedicated privileged administrator role changed")

if end["emergency_access_governance_defined"] is not True:
    fail("emergency governance must remain defined")

if end["emergency_access_live_recovery_path_operational"] is not False:
    fail("live emergency recovery path incorrectly claimed")

if end["bootstrap_global_administrator_retained"] is not True:
    fail("bootstrap Global Administrator must remain retained")

if end["bootstrap_reduction_permitted"] is not False:
    fail("bootstrap reduction prematurely permitted")


future = evidence["future_resume_gate"]

if future["independent_phishing_resistant_credential_required"] is not True:
    fail("future phishing-resistant credential gate missing")

if future["fresh_tenant_validation_required"] is not True:
    fail("future tenant revalidation gate missing")

if future["explicit_authorization_required"] is not True:
    fail("future authorization gate missing")


tenant_changes = evidence["tenant_changes"]

integer_zero_keys = (
    "accounts_enabled",
    "passwords_changed",
    "authentication_methods_registered",
    "roles_assigned",
    "groups_modified",
    "licenses_modified",
)

for key in integer_zero_keys:
    if tenant_changes[key] != 0:
        fail(f"unexpected Feature 5D2-D tenant change: {key}")

boolean_false_keys = (
    "conditional_access_modified",
    "pim_modified",
    "bootstrap_admin_modified",
)

for key in boolean_false_keys:
    if tenant_changes[key] is not False:
        fail(f"unexpected Feature 5D2-D control change: {key}")


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
    ("rbac", rbac_raw),
    ("evidence", evidence_raw),
):
    if email_pattern.search(raw):
        fail(f"complete UPN/email detected in {name}")

    if guid_pattern.search(raw):
        fail(f"GUID detected in {name}")


print("PASS: Feature 5 emergency-access deferral valid.")
print("PASS: two emergency accounts remain disabled.")
print("PASS: emergency roles remain zero.")
print("PASS: emergency groups remain zero.")
print("PASS: emergency licenses remain zero.")
print("PASS: no weak authentication substitute accepted.")
print("PASS: future phishing-resistant requirement preserved.")
print(
    "PASS: physical FIDO2 remains a documented future option only."
)
print(
    "PASS: device-bound passkey remains a documented future option only."
)
print("PASS: no future authentication option is implemented.")
print("PASS: Global Administrator baseline remains one.")
print("PASS: bootstrap Global Administrator retained.")
print("PASS: bootstrap reduction remains blocked.")
print("PASS: Feature 5D2-D tenant writes = 0.")
print("PASS: no tenant identifier or secret detected.")
