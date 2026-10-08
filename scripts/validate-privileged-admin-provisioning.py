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

privileged = (
    config["principals"]["privileged_admin_01"]
)

if (
    privileged["logical_id"]
    != "PRIVILEGED_ADMIN_01"
):
    fail("unexpected logical identity")

if (
    privileged["provisioning_state"]
    != "created-unprivileged-auth-pending"
):
    fail("unexpected provisioning state")

if privileged["current_directory_role"] is not None:
    fail(
        "directory role exists before "
        "strong-authentication validation"
    )

if (
    privileged["strong_authentication_state"]
    != "pending-first-sign-in-registration"
):
    fail(
        "strong-authentication state must remain pending"
    )

if privileged["initial_sign_in_complete"] is not False:
    fail(
        "initial sign-in must remain incomplete in 5C2"
    )

if (
    privileged["initial_feature5_role"]
    != "Privileged Role Administrator"
):
    fail("future target role changed unexpectedly")

if evidence["feature"] != "5":
    fail("unexpected evidence feature")

if evidence["phase"] != "5C2":
    fail("unexpected evidence phase")

provisioning = evidence["provisioning"]

if provisioning["identity_created"] is not True:
    fail("identity creation not validated")

if provisioning["read_back_complete"] is not True:
    fail("identity read-back not validated")

if provisioning["license_count"] != 0:
    fail("privileged identity must remain unlicensed")

if provisioning["group_membership_count"] != 0:
    fail(
        "privileged identity has unexpected group membership"
    )

if provisioning["directory_role_assignment_count"] != 0:
    fail(
        "privileged identity has premature directory role"
    )

if provisioning["initial_sign_in_completed"] is not False:
    fail("initial sign-in cannot be complete in 5C2")

if (
    provisioning["strong_authentication_state"]
    != "pending-first-sign-in-registration"
):
    fail("unexpected strong-authentication state")

guardrail = evidence["role_guardrail"]

if guardrail["role_assigned_during_5c2"] is not False:
    fail("role assignment occurred during 5C2")

if (
    guardrail[
        "global_administrator_assigned_to_new_identity"
    ]
    is not False
):
    fail(
        "new identity must not receive Global Administrator"
    )

if guardrail["pim_configured"] is not False:
    fail("PIM cannot be configured during 5C2")

baseline = evidence["baseline_after"]

if baseline["global_administrator_assignment_count"] != 1:
    fail(
        "Global Administrator baseline changed"
    )

if (
    baseline["bootstrap_global_administrator_changed"]
    is not False
):
    fail("bootstrap Global Administrator changed")

if any(
    evidence["unchanged_controls"].values()
):
    fail("a protected control changed during 5C2")

credentials = evidence["credential_handling"]

for key in (
    "temporary_password_in_repository",
    "temporary_password_in_evidence",
    "temporary_password_in_terminal_output",
    "temporary_password_in_chat",
):
    if credentials[key] is not False:
        fail(f"unsafe credential handling: {key}")

if credentials["password_manager_used"] is not True:
    fail("password-manager confirmation missing")

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
        fail(
            f"complete email/UPN detected in {name}"
        )

    if guid_pattern.search(raw):
        fail(
            f"GUID detected in {name}"
        )

print("PASS: Feature 5C2 provisioning state valid.")
print("PASS: PRIVILEGED_ADMIN_01 exists but remains unprivileged.")
print("PASS: directory-role assignment count remains zero.")
print("PASS: license count remains zero.")
print("PASS: group-membership count remains zero.")
print("PASS: Global Administrator baseline remains one.")
print("PASS: strong authentication remains pending.")
print("PASS: Feature 5C2 contains no tenant identifier or secret.")
