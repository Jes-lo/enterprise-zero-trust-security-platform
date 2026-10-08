#!/usr/bin/env python3

import json
import re
import sys
from pathlib import Path


def fail(message: str) -> None:
    raise SystemExit(f"FAIL: {message}")


if len(sys.argv) != 3:
    fail(
        "usage: validate-privileged-admin-role-assignment.py "
        "<config.json> <role-evidence.json>"
    )


config_path = Path(sys.argv[1])
evidence_path = Path(sys.argv[2])

if not config_path.is_file():
    fail("config missing")

if not evidence_path.is_file():
    fail("role evidence missing")


config_raw = config_path.read_text()
evidence_raw = evidence_path.read_text()

config = json.loads(config_raw)
evidence = json.loads(evidence_raw)

principal = config["principals"]["privileged_admin_01"]

if principal["logical_id"] != "PRIVILEGED_ADMIN_01":
    fail("unexpected logical identity")

if (
    principal["provisioning_state"]
    != "created-privileged-auth-ready"
):
    fail("principal is not in privileged auth-ready state")

if (
    principal["current_directory_role"]
    != "Privileged Role Administrator"
):
    fail("current directory role must be exactly PRA")

if (
    principal["initial_feature5_role"]
    != "Privileged Role Administrator"
):
    fail("planned Feature 5 role changed unexpectedly")

if (
    principal["current_role_assignment_model"]
    != "active-static-interim"
):
    fail("unexpected current assignment model")

if principal["current_role_scope"] != "tenant":
    fail("unexpected current role scope")

if principal["pim_configured"] is not False:
    fail("PIM must remain false during Feature 5")

if (
    principal["strong_authentication_state"]
    != "validated-authenticator-and-device-bound-passkey"
):
    fail("strong authentication readiness lost")

if principal["initial_sign_in_complete"] is not True:
    fail("initial sign-in state invalid")

if evidence["feature"] != "5":
    fail("unexpected evidence feature")

if evidence["phase"] != "5C5-5C6":
    fail("unexpected evidence phase")

subject = evidence["principal"]

if subject["logical_id"] != "PRIVILEGED_ADMIN_01":
    fail("unexpected evidence principal")

if subject["strong_authentication_ready"] is not True:
    fail("strong-authentication readiness missing")

pre = evidence["pre_assignment_state"]

if pre["directory_role_assignment_count"] != 0:
    fail("pre-assignment role count must be zero")

if pre["group_membership_count"] != 0:
    fail("pre-assignment group count must be zero")

if pre["license_count"] != 0:
    fail("pre-assignment license count must be zero")

assignment = evidence["assignment"]

if assignment["authorized_write_count"] != 1:
    fail("exactly one role-assignment write is required")

if assignment["operation"] != "assign-directory-role":
    fail("unexpected write operation")

if assignment["role"] != "Privileged Role Administrator":
    fail("unexpected assigned role")

if assignment["scope"] != "tenant":
    fail("unexpected role scope")

if assignment["assignment_state"] != "active":
    fail("assignment must be active")

if assignment["assignment_model"] != "active-static-interim":
    fail("unexpected assignment model")

if assignment["pim"] is not False:
    fail("PIM must not be configured in Feature 5")

if assignment["completed"] is not True:
    fail("role assignment not completed")

post = evidence["post_assignment_state"]

if post["directory_role_assignment_count"] != 1:
    fail("post-assignment role count must be one")

if (
    post["expected_directory_role"]
    != "Privileged Role Administrator"
):
    fail("post-assignment role is not PRA")

if post["global_administrator_assigned_to_principal"] is not False:
    fail("privileged identity must not receive Global Administrator")

if post["group_membership_count"] != 0:
    fail("privileged identity must remain outside groups")

if post["license_count"] != 0:
    fail("privileged identity must remain unlicensed")

if post["microsoft_authenticator_present"] is not True:
    fail("Microsoft Authenticator missing")

if post["device_bound_passkey_present"] is not True:
    fail("device-bound passkey missing")

if post["global_administrator_assignment_count"] != 1:
    fail("Global Administrator baseline changed")

if post["security_defaults_enabled"] is not True:
    fail("Security Defaults changed")

functional = evidence["functional_validation"]

if functional["fresh_passkey_sign_in_successful"] is not True:
    fail("fresh passkey sign-in not validated")

if functional["roles_and_administrators_access_successful"] is not True:
    fail("PRA functional access not validated")

if (
    functional[
        "privileged_role_administrator_assignments_read_successful"
    ]
    is not True
):
    fail("role-assignment read access not validated")

if (
    functional[
        "administrative_writes_performed_during_functional_test"
    ]
    != 0
):
    fail("functional test performed an unauthorized write")

if any(evidence["unchanged_controls"].values()):
    fail("protected control changed")

authorization = evidence["authorization_state_after"]

if authorization["feature5c5_authorization_consumed"] is not True:
    fail("5C5 authorization not consumed")

if authorization["additional_role_assignment_authorized"] is not False:
    fail("additional role assignment is unexpectedly authorized")

if authorization["bootstrap_reduction_authorized"] is not False:
    fail("bootstrap reduction is unexpectedly authorized")

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
    ("role evidence", evidence_raw),
):
    if email_pattern.search(raw):
        fail(f"complete UPN/email detected in {name}")

    if guid_pattern.search(raw):
        fail(f"GUID detected in {name}")

print("PASS: Feature 5C5/5C6 role assignment evidence valid.")
print("PASS: current role = Privileged Role Administrator.")
print("PASS: assignment model = active-static-interim.")
print("PASS: assignment scope = tenant.")
print("PASS: PIM remains disabled/deferred.")
print("PASS: role count changed 0 -> 1.")
print("PASS: groups remain zero.")
print("PASS: licenses remain zero.")
print("PASS: Global Administrator not assigned to privileged admin.")
print("PASS: Global Administrator baseline remains one.")
print("PASS: strong authentication remains intact.")
print("PASS: passkey functional sign-in validated.")
print("PASS: PRA functional read access validated.")
print("PASS: functional administrative writes = 0.")
print("PASS: Security Defaults remains enabled.")
print("PASS: no tenant identifier or secret detected.")
