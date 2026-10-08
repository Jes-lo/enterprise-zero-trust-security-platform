#!/usr/bin/env python3

import json
import re
import sys
from pathlib import Path


def fail(message: str) -> None:
    raise SystemExit(f"FAIL: {message}")


if len(sys.argv) != 4:
    fail(
        "usage: validate-privileged-admin-group-remediation.py "
        "<config.json> <auth-evidence.json> "
        "<remediation-evidence.json>"
    )


config_path = Path(sys.argv[1])
auth_path = Path(sys.argv[2])
remediation_path = Path(sys.argv[3])

for path in (
    config_path,
    auth_path,
    remediation_path,
):
    if not path.is_file():
        fail(f"missing file: {path}")


config_raw = config_path.read_text()
auth_raw = auth_path.read_text()
remediation_raw = remediation_path.read_text()

config = json.loads(config_raw)
auth = json.loads(auth_raw)
remediation = json.loads(remediation_raw)

principal = config["principals"]["privileged_admin_01"]

if principal["logical_id"] != "PRIVILEGED_ADMIN_01":
    fail("unexpected logical identity")

if (
    principal["provisioning_state"]
    != "created-unprivileged-auth-ready"
):
    fail("privileged identity is not auth-ready")

if principal["current_directory_role"] is not None:
    fail("directory role assigned before Feature 5C5")

if (
    principal["strong_authentication_state"]
    != "validated-authenticator-and-device-bound-passkey"
):
    fail("strong authentication state changed")

if auth["phase"] != "5C3-5C4":
    fail("unexpected authentication evidence phase")

if auth["tenant_state_after"]["group_membership_count"] != 1:
    fail("correct historical group count must be one")

correction = auth.get("correction_notice")

if not isinstance(correction, dict):
    fail("authentication evidence correction missing")

if correction["status"] != "corrected-by-feature-5C4-R1":
    fail("authentication evidence correction status invalid")

if (
    correction["correct_historical_group_membership_count"]
    != 1
):
    fail("corrected historical membership count invalid")

if remediation["feature"] != "5":
    fail("unexpected remediation feature")

if remediation["phase"] != "5C4-R1":
    fail("unexpected remediation phase")

subject = remediation["principal"]

if subject["logical_id"] != "PRIVILEGED_ADMIN_01":
    fail("unexpected remediation principal")

discrepancy = remediation["discovered_discrepancy"]

if discrepancy["historical_recorded_group_membership_count"] != 0:
    fail("original incorrect assertion not preserved")

if discrepancy["correct_historical_group_membership_count"] != 1:
    fail("historical corrected group count invalid")

if discrepancy["group_display_name"] != "Portfolio Project Lab":
    fail("unexpected group")

if discrepancy["group_type"] != "Microsoft 365":
    fail("unexpected group type")

if discrepancy["membership_type"] != "Assigned":
    fail("unexpected membership type")

if discrepancy["source"] != "Cloud":
    fail("unexpected group source")

if discrepancy["group_member_count_before"] != 10:
    fail("unexpected pre-remediation member count")

write = remediation["remediation"]

if write["authorized_write_count"] != 1:
    fail("remediation must contain exactly one tenant write")

if write["operation"] != "remove-user-from-group":
    fail("unexpected remediation operation")

if write["target_principal"] != "PRIVILEGED_ADMIN_01":
    fail("unexpected remediation target")

if write["target_group"] != "Portfolio Project Lab":
    fail("unexpected remediation group")

if write["completed"] is not True:
    fail("remediation not complete")

if write["other_group_members_modified"] is not False:
    fail("other group members were modified")

if write["group_deleted_or_modified"] is not False:
    fail("group itself was unexpectedly modified")

post = remediation["post_remediation_state"]

if post["principal_group_membership_count"] != 0:
    fail("privileged identity still has group membership")

if post["group_member_count_after"] != 9:
    fail("unexpected post-remediation group member count")

if post["directory_role_assignment_count"] != 0:
    fail("directory role assigned before Feature 5C5")

if post["license_count"] != 0:
    fail("unexpected license")

if post["microsoft_authenticator_present"] is not True:
    fail("Microsoft Authenticator missing")

if post["device_bound_passkey_present"] is not True:
    fail("device-bound passkey missing")

if post["global_administrator_assignment_count"] != 1:
    fail("Global Administrator baseline changed")

if post["security_defaults_enabled"] is not True:
    fail("Security Defaults changed")

if any(remediation["unchanged_controls"].values()):
    fail("protected control changed")

authorization = remediation["authorization_state_after"]

if authorization["feature5c4_r1_consumed"] is not True:
    fail("5C4-R1 authorization not consumed")

if authorization["feature5c5_role_assignment_authorized"] is not False:
    fail("Feature 5C5 was prematurely authorized")

if authorization["bootstrap_reduction_authorized"] is not False:
    fail("bootstrap reduction was prematurely authorized")

if any(remediation["privacy"].values()):
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
    ("authentication evidence", auth_raw),
    ("remediation evidence", remediation_raw),
):
    if email_pattern.search(raw):
        fail(f"complete UPN/email detected in {name}")

    if guid_pattern.search(raw):
        fail(f"GUID detected in {name}")

print("PASS: Feature 5C4-R1 remediation evidence valid.")
print("PASS: historical discrepancy transparently preserved.")
print("PASS: pre-remediation privileged-admin groups = 1.")
print("PASS: post-remediation privileged-admin groups = 0.")
print("PASS: group member count changed 10 -> 9.")
print("PASS: exactly one membership-removal write recorded.")
print("PASS: directory roles remain zero.")
print("PASS: licenses remain zero.")
print("PASS: strong authentication remains intact.")
print("PASS: Global Administrator baseline remains one.")
print("PASS: Security Defaults remains enabled.")
print("PASS: Feature 5C5 remains unauthorized.")
print("PASS: no tenant identifier or secret detected.")
