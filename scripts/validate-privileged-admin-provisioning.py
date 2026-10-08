#!/usr/bin/env python3

import json
import re
import sys
from pathlib import Path


def fail(message: str) -> None:
    raise SystemExit(f"FAIL: {message}")


if len(sys.argv) != 3:
    fail(
        "usage: validate-privileged-admin-provisioning.py "
        "<config.json> <evidence.json>"
    )

config_path = Path(sys.argv[1])
evidence_path = Path(sys.argv[2])

if not config_path.is_file():
    fail("config file missing")

if not evidence_path.is_file():
    fail("evidence file missing")

config_raw = config_path.read_text()
evidence_raw = evidence_path.read_text()

config = json.loads(config_raw)
evidence = json.loads(evidence_raw)

principal = config["principals"]["privileged_admin_01"]

if principal["logical_id"] != "PRIVILEGED_ADMIN_01":
    fail("unexpected logical identity")

current_role = principal["current_directory_role"]
state = principal["provisioning_state"]
auth_state = principal["strong_authentication_state"]
initial_sign_in = principal["initial_sign_in_complete"]

if (
    principal["initial_feature5_role"]
    != "Privileged Role Administrator"
):
    fail("planned Feature 5 role changed unexpectedly")

allowed_states = {
    "created-unprivileged-auth-pending",
    "created-unprivileged-auth-ready",
    "created-privileged-auth-ready",
}

if state not in allowed_states:
    fail("unexpected privileged-admin provisioning state")

if state == "created-unprivileged-auth-pending":
    if current_role is not None:
        fail("pending identity cannot have a directory role")

    if auth_state != "pending-first-sign-in-registration":
        fail("pending provisioning/authentication state mismatch")

    if initial_sign_in is not False:
        fail("pending identity cannot have completed initial sign-in")

if state == "created-unprivileged-auth-ready":
    if current_role is not None:
        fail("unprivileged auth-ready identity cannot have a role")

    if (
        auth_state
        != "validated-authenticator-and-device-bound-passkey"
    ):
        fail("ready provisioning/authentication state mismatch")

    if initial_sign_in is not True:
        fail("ready identity must have completed initial sign-in")

if state == "created-privileged-auth-ready":
    if current_role != "Privileged Role Administrator":
        fail("privileged state requires exactly PRA")

    if (
        auth_state
        != "validated-authenticator-and-device-bound-passkey"
    ):
        fail("privileged authentication state mismatch")

    if initial_sign_in is not True:
        fail("privileged identity must have completed sign-in")

if evidence["feature"] != "5":
    fail("unexpected evidence feature")

if evidence["phase"] != "5C2":
    fail("unexpected historical evidence phase")

provisioning = evidence["provisioning"]

if provisioning["identity_created"] is not True:
    fail("Feature 5C2 identity creation not validated")

if provisioning["read_back_complete"] is not True:
    fail("Feature 5C2 read-back not validated")

if provisioning["license_count"] != 0:
    fail("Feature 5C2 identity unexpectedly licensed")

if provisioning["group_membership_count"] != 0:
    fail("Feature 5C2 unexpected group membership")

if provisioning["directory_role_assignment_count"] != 0:
    fail("Feature 5C2 contained premature directory role")

if provisioning["initial_sign_in_completed"] is not False:
    fail("Feature 5C2 initial sign-in historical state changed")

if (
    provisioning["strong_authentication_state"]
    != "pending-first-sign-in-registration"
):
    fail("Feature 5C2 historical authentication state changed")

guardrail = evidence["role_guardrail"]

if guardrail["role_assigned_during_5c2"] is not False:
    fail("role assignment occurred during Feature 5C2")

if (
    guardrail[
        "global_administrator_assigned_to_new_identity"
    ]
    is not False
):
    fail("Feature 5C2 assigned Global Administrator")

if guardrail["pim_configured"] is not False:
    fail("PIM was configured during Feature 5C2")

baseline = evidence["baseline_after"]

if baseline["global_administrator_assignment_count"] != 1:
    fail("Feature 5C2 Global Administrator baseline changed")

if (
    baseline["bootstrap_global_administrator_changed"]
    is not False
):
    fail("Feature 5C2 bootstrap assignment changed")

if any(evidence["unchanged_controls"].values()):
    fail("Feature 5C2 protected control changed")

credentials = evidence["credential_handling"]

for key in (
    "temporary_password_in_repository",
    "temporary_password_in_evidence",
    "temporary_password_in_terminal_output",
    "temporary_password_in_chat",
):
    if credentials[key] is not False:
        fail(f"unsafe Feature 5C2 credential handling: {key}")

if credentials["password_manager_used"] is not True:
    fail("Feature 5C2 password-manager confirmation missing")

if any(evidence["privacy"].values()):
    fail("Feature 5C2 privacy control violation")

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
        fail(f"complete email/UPN detected in {name}")

    if guid_pattern.search(raw):
        fail(f"GUID detected in {name}")

print("PASS: Feature 5C2 historical provisioning evidence valid.")
print("PASS: current privileged-admin progression state is valid.")
print("PASS: current progression state and role are valid.")
print("PASS: Feature 5C2 historical role count remains zero.")
print("PASS: Feature 5C2 Global Administrator baseline remains one.")
print("PASS: no tenant identifier or secret detected.")
