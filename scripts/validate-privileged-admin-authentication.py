#!/usr/bin/env python3

import json
import re
import sys
from pathlib import Path


def fail(message: str) -> None:
    raise SystemExit(f"FAIL: {message}")


if len(sys.argv) != 3:
    fail(
        "usage: validate-privileged-admin-authentication.py "
        "<config.json> <evidence.json>"
    )

config_path = Path(sys.argv[1])
evidence_path = Path(sys.argv[2])

if not config_path.is_file():
    fail("config file missing")

if not evidence_path.is_file():
    fail("authentication evidence file missing")

config_raw = config_path.read_text()
evidence_raw = evidence_path.read_text()

config = json.loads(config_raw)
evidence = json.loads(evidence_raw)

principal = config["principals"]["privileged_admin_01"]

if principal["logical_id"] != "PRIVILEGED_ADMIN_01":
    fail("unexpected logical identity")

if (
    principal["provisioning_state"]
    != "created-unprivileged-auth-ready"
):
    fail("privileged admin is not in auth-ready state")

if principal["current_directory_role"] is not None:
    fail("directory role assigned before Feature 5C5")

if (
    principal["strong_authentication_state"]
    != "validated-authenticator-and-device-bound-passkey"
):
    fail("strong-authentication state not validated")

if principal["initial_sign_in_complete"] is not True:
    fail("initial sign-in is not complete")

if (
    principal["initial_feature5_role"]
    != "Privileged Role Administrator"
):
    fail("planned Feature 5 role changed unexpectedly")

if evidence["feature"] != "5":
    fail("unexpected feature")

if evidence["phase"] != "5C3-5C4":
    fail("unexpected evidence phase")

subject = evidence["principal"]

if subject["logical_id"] != "PRIVILEGED_ADMIN_01":
    fail("unexpected evidence identity")

if subject["initial_sign_in_complete"] is not True:
    fail("initial sign-in evidence missing")

if subject["temporary_password_transition_complete"] is not True:
    fail("temporary password transition not validated")

authentication = evidence["authentication"]

required_auth = (
    "microsoft_authenticator_registered",
    "device_bound_passkey_registered",
    "device_bound_passkey_sign_in_tested",
    "passwordless_passkey_test_successful",
    "strong_authentication_ready",
)

for key in required_auth:
    if authentication[key] is not True:
        fail(f"authentication requirement not met: {key}")

authorization = evidence["authorization_state_after"]

if authorization["directory_role_assignment_count"] != 0:
    fail("privileged identity has premature directory role")

if (
    authorization["planned_future_role"]
    != "Privileged Role Administrator"
):
    fail("unexpected planned role")

if authorization["planned_future_role_assigned"] is not False:
    fail("PRA assigned before Feature 5C5")

if (
    authorization[
        "global_administrator_assigned_to_new_identity"
    ]
    is not False
):
    fail("new identity received Global Administrator")

if authorization["pim_configured"] is not False:
    fail("PIM configured before Feature 7")

tenant = evidence["tenant_state_after"]

if tenant["group_membership_count"] != 0:
    fail("unexpected group membership")

if tenant["license_count"] != 0:
    fail("unexpected license")

if tenant["global_administrator_assignment_count"] != 1:
    fail("Global Administrator baseline changed")

if tenant["security_defaults_enabled"] is not True:
    fail("Security Defaults no longer enabled")

if any(evidence["unchanged_controls"].values()):
    fail("protected control changed")

credentials = evidence["credential_handling"]

for key, value in credentials.items():
    if key == "password_manager_used":
        if value is not True:
            fail("password manager confirmation missing")
        continue

    if value is not False:
        fail(f"unsafe credential handling: {key}")

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
        fail(f"complete email/UPN detected in {name}")

    if guid_pattern.search(raw):
        fail(f"GUID detected in {name}")

print("PASS: Feature 5C3/5C4 authentication state valid.")
print("PASS: initial sign-in complete.")
print("PASS: temporary password transition complete.")
print("PASS: Microsoft Authenticator registered.")
print("PASS: device-bound passkey registered.")
print("PASS: passwordless passkey sign-in successfully tested.")
print("PASS: current directory roles remain zero.")
print("PASS: groups and licenses remain zero.")
print("PASS: Global Administrator baseline remains one.")
print("PASS: Security Defaults remains enabled.")
print("PASS: no tenant identifier or secret detected.")
