#!/usr/bin/env python3

import json
import re
import sys
from pathlib import Path


def fail(message: str) -> None:
    raise SystemExit(f"FAIL: {message}")


if len(sys.argv) != 4:
    fail(
        "usage: validate-emergency-access-baseline.py "
        "<identity.json> <rbac.json> <evidence.json>"
    )


identity_path = Path(sys.argv[1])
rbac_path = Path(sys.argv[2])
evidence_path = Path(sys.argv[3])

for path in (
    identity_path,
    rbac_path,
    evidence_path,
):
    if not path.is_file():
        fail(f"missing file: {path}")


identity_raw = identity_path.read_text()
rbac_raw = rbac_path.read_text()
evidence_raw = evidence_path.read_text()

identity = json.loads(identity_raw)
rbac = json.loads(rbac_raw)
evidence = json.loads(evidence_raw)

expected_ids = {
    "EMERGENCY_ADMIN_01",
    "EMERGENCY_ADMIN_02",
}

accounts = [
    item
    for item in identity["accounts"]
    if item["persona"] == "EMERGENCY_ADMIN"
]

if len(accounts) != 2:
    fail("identity foundation must contain two emergency identities")

account_ids = {
    item["id"]
    for item in accounts
}

if account_ids != expected_ids:
    fail("identity foundation emergency IDs changed")

for item in accounts:
    if item["cloud_only"] is not True:
        fail("emergency identity must be cloud-only")

    if item["license_policy"] != "unlicensed":
        fail("emergency identity must remain unlicensed")

    if item["privilege_class"] != "PC0":
        fail("emergency identity must remain PC0")

    if item["user_type"] != "Member":
        fail("emergency identity must remain Member")

    if item["intended_use"] != "emergency-access-only":
        fail("emergency intended use changed")


emergency = rbac["principals"]["emergency_access"]

if set(emergency["logical_ids"]) != expected_ids:
    fail("RBAC emergency IDs do not match identity foundation")

if emergency["target_count"] != 2:
    fail("emergency target count must be two")

if (
    emergency["current_operational_state"]
    != "created-disabled-unlicensed-unprivileged-auth-pending"
):
    fail("unexpected current emergency operational state")

if emergency["current_account_enabled_count"] != 0:
    fail("emergency identities unexpectedly enabled")

if emergency["current_directory_role_assignment_count"] != 0:
    fail("emergency identities unexpectedly privileged")

if emergency["current_group_membership_count"] != 0:
    fail("emergency identities unexpectedly grouped")

if emergency["current_license_count"] != 0:
    fail("emergency identities unexpectedly licensed")

if (
    emergency["strong_authentication_state"]
    != "pending-emergency-onboarding"
):
    fail("unexpected emergency authentication state")

if emergency["target_role"] != "Global Administrator":
    fail("emergency recovery role must remain Global Administrator")

if (
    emergency["target_role_assignment_model"]
    != "permanent-active-emergency"
):
    fail("unexpected emergency role assignment model")

if (
    emergency["pim_target_state"]
    != "permanent-active-not-eligible"
):
    fail("emergency account cannot depend on eligible PIM activation")

if (
    emergency["authentication_requirement"]
    != "phishing-resistant-independent-from-routine-admin"
):
    fail("emergency authentication independence requirement missing")

if emergency["normal_admin_authentication_dependency_allowed"] is not False:
    fail("emergency access cannot depend on routine admin authentication")

if emergency["conditional_access_exclusion_owner_feature"] != 6:
    fail("Conditional Access emergency treatment must remain Feature 6")

if emergency["validation_interval_days"] != 90:
    fail("emergency validation interval must remain 90 days")

if emergency["routine_use"] is not False:
    fail("emergency identities cannot be routine-use accounts")

if emergency["requires_separate_explicit_gate"] is not True:
    fail("emergency writes require explicit gate")


if evidence["feature"] != "5":
    fail("unexpected evidence feature")

if evidence["phase"] != "5D1":
    fail("unexpected evidence phase")

correction = evidence["contract_correction"]

if correction["tenant_objects_changed_by_correction"] is not False:
    fail("contract correction must not change tenant objects")

if set(
    correction[
        "authoritative_identity_foundation_logical_ids"
    ]
) != expected_ids:
    fail("evidence authoritative emergency IDs invalid")


ea = evidence["emergency_access"]

if ea["principal_count"] != 2:
    fail("evidence emergency principal count invalid")

if set(ea["logical_ids"]) != expected_ids:
    fail("evidence emergency IDs invalid")

current = ea["current_state"]

expected_current = {
    "existing_identity_count": 2,
    "enabled_identity_count": 0,
    "member_user_type_count": 2,
    "directory_role_assignment_count": 0,
    "group_membership_count": 0,
    "license_count": 0,
    "registered_strong_authentication_identity_count": 0,
}

if current != expected_current:
    fail("unexpected current emergency-access tenant state")

credentials = ea["protected_local_credentials"]

if credentials["credential_record_count"] != 2:
    fail("two protected emergency credential records required")

if credentials["force_change_on_first_sign_in_count"] != 2:
    fail("both emergency credentials must require password transition")

if credentials["initially_disabled_record_count"] != 2:
    fail("both emergency records must reflect disabled provisioning")

if credentials["credential_values_exposed"] is not False:
    fail("credential values must not be exposed")

if credentials["credential_values_tracked"] is not False:
    fail("credential values must not be tracked")


target = ea["target_state"]

if target["enabled_identity_count"] != 2:
    fail("target requires two operational emergency identities")

if target["target_role"] != "Global Administrator":
    fail("target emergency role changed")

if (
    target["target_role_assignment_model"]
    != "permanent-active-emergency"
):
    fail("target assignment model changed")

if target["pim_eligible_assignment"] is not False:
    fail("emergency access cannot depend on eligible PIM activation")

if (
    target["authentication_requirement"]
    != "phishing-resistant-independent-from-routine-admin"
):
    fail("target emergency authentication requirement changed")

if target["routine_use"] is not False:
    fail("emergency accounts cannot be routine-use accounts")

if target["license_count"] != 0:
    fail("emergency accounts must remain unlicensed")

if target["group_membership_count"] != 0:
    fail("emergency accounts must remain outside ordinary groups")

if target["conditional_access_exclusion_owner_feature"] != 6:
    fail("CA emergency exclusions must remain Feature 6")

if target["validation_interval_days"] != 90:
    fail("emergency validation cadence changed")


tenant = evidence["tenant_baseline"]

if tenant["global_administrator_assignment_count"] != 1:
    fail("pre-operationalization GA baseline must remain one")

if tenant["security_defaults_enabled"] is not True:
    fail("Security Defaults unexpectedly disabled")


if any(evidence["feature_boundaries"].values()):
    fail("Feature 5D1 performed an unauthorized live change")

authorization = evidence["authorization"]

if (
    authorization[
        "feature5d2_emergency_operationalization_authorized"
    ]
    is not False
):
    fail("Feature 5D2 prematurely authorized")

if authorization["global_administrator_assignment_authorized"] is not False:
    fail("emergency GA assignment prematurely authorized")

if authorization["bootstrap_reduction_authorized"] is not False:
    fail("bootstrap reduction prematurely authorized")

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
    ("identity", identity_raw),
    ("rbac", rbac_raw),
    ("evidence", evidence_raw),
):
    if email_pattern.search(raw):
        fail(f"complete UPN/email detected in {name}")

    if guid_pattern.search(raw):
        fail(f"GUID detected in {name}")


print("PASS: Feature 5D1 emergency-access baseline valid.")
print("PASS: emergency IDs align with identity foundation.")
print("PASS: two emergency identities exist.")
print("PASS: both currently disabled.")
print("PASS: current emergency roles = 0.")
print("PASS: current emergency groups = 0.")
print("PASS: current emergency licenses = 0.")
print("PASS: emergency strong authentication remains pending.")
print("PASS: target role = Global Administrator.")
print("PASS: target assignment = permanent active emergency.")
print("PASS: eligible PIM dependency = false.")
print("PASS: CA treatment remains Feature 6.")
print("PASS: bootstrap reduction remains blocked.")
print("PASS: no tenant identifier or secret detected.")
