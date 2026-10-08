#!/usr/bin/env bash

set -euo pipefail

echo "=================================================="
echo "PASSKEY PILOT VALIDATION"
echo "=================================================="

CONFIG="configs/authentication-mfa.json"
VERIFIER="automation/powershell/Test-AuthenticationPasskeyPilot.ps1"
RUNBOOK="docs/security/authentication-passkey-pilot-runbook.md"
EVIDENCE="docs/evidence/authentication-passkey-pilot-validation.json"

for path in \
  "$CONFIG" \
  "$VERIFIER" \
  "$RUNBOOK"
do
  [[ -s "$path" ]] || {
    echo "FAIL: missing Feature 4D artifact: $path"
    exit 1
  }

  echo "PASS: $path"
done

echo
echo "===== FEATURE 4D CONTRACT ====="

python3 - <<'PY'
import json
from pathlib import Path

data = json.loads(
    Path(
        "configs/authentication-mfa.json"
    ).read_text()
)

pilot = data["passkey_pilot"]

assert pilot["phase"] == "feature4d"
assert pilot["mode"] == "controlled_user_interactive"
assert pilot["pilot_account_id"] == "EMPLOYEE_01"
assert pilot["pilot_privilege_class"] == "PC3"

assert (
    pilot["target_method"]
    == "microsoft_authenticator_passkey"
)

assert pilot["target_passkey_type"] == "deviceBound"
assert pilot["phishing_resistant_target"] is True
assert pilot["registration_user_interactive"] is True
assert pilot["policy_change_required"] is False

for key in (
    "security_defaults_change_allowed",
    "authentication_policy_change_allowed",
    "conditional_access_change_allowed",
    "privileged_role_change_allowed",
    "emergency_identity_use_allowed",
    "existing_mfa_removal_allowed",
    "existing_fallback_removal_allowed",
):
    assert pilot[key] is False, key

policy = pilot["policy_assessment"]

assert policy["mode"] == "read_only"

assert policy["delegated_scopes"] == [
    "Policy.Read.AuthenticationMethod"
]

assert (
    policy["resource"]
    == (
        "/policies/authenticationMethodsPolicy/"
        "authenticationMethodConfigurations/fido2"
    )
)

assert policy["resource_writes_allowed"] is False

verification = pilot["verification"]

assert (
    verification["mode"]
    == "signed_in_user_self_read"
)

assert verification["delegated_scopes"] == [
    "UserAuthMethod-Passkey.Read",
    "UserAuthenticationMethod.Read",
]

assert verification["resources"] == [
    "/me/authentication/fido2Methods",
    "/me/authentication/methods",
]

assert (
    verification["resource_writes_allowed"]
    is False
)

print("PASS: Feature 4D contract validated.")
PY

echo
echo "===== POWERSHELL SYNTAX ====="

pwsh \
  -NoProfile \
  -NonInteractive \
  -Command '
$tokens = $null
$errors = $null

[System.Management.Automation.Language.Parser]::ParseFile(
    "automation/powershell/Test-AuthenticationPasskeyPilot.ps1",
    [ref]$tokens,
    [ref]$errors
) | Out-Null

if ($errors.Count -gt 0) {
    foreach ($item in $errors) {
        Write-Host (
            "FAIL line=" +
            $item.Extent.StartLineNumber +
            " column=" +
            $item.Extent.StartColumnNumber +
            " message=" +
            $item.Message
        )
    }

    exit 1
}

Write-Host "PASS: Feature 4D verifier syntax valid."
'

echo
echo "===== LEAST-PRIVILEGE READ SURFACE ====="

python3 - <<'PY'
from pathlib import Path

text = Path(
    "automation/powershell/"
    "Test-AuthenticationPasskeyPilot.ps1"
).read_text()

required = (
    '"Policy.Read.AuthenticationMethod"',
    '"UserAuthMethod-Passkey.Read"',
    '"UserAuthenticationMethod.Read"',
    "authenticationMethodConfigurations/fido2",
    "me/authentication/fido2Methods",
    "me/authentication/methods",
    "-UseDeviceAuthentication",
    "-Method GET",
    "Wrong account authenticated",
)

for marker in required:
    assert marker in text, marker

for forbidden in (
    "Policy.ReadWrite.AuthenticationMethod",
    "UserAuthenticationMethod.Read.All",
    "UserAuthenticationMethod.ReadWrite",
    "UserAuthenticationMethod.ReadWrite.All",
    "Directory.Read.All",
    "-Method POST",
    "-Method PATCH",
    "-Method PUT",
    "-Method DELETE",
):
    assert forbidden not in text, forbidden

print("PASS: policy assessment is read-only.")
print("PASS: pilot verification is signed-user self-read.")
print("PASS: no Graph write verb present.")
PY

if [[ ! -e "$EVIDENCE" ]]; then
  echo
  echo "INFO: live Feature 4D evidence not present yet."
  echo "PASS: Feature 4D pre-live validation complete."
  exit 0
fi

echo
echo "===== LIVE PASSKEY PILOT EVIDENCE ====="

python3 - <<'PY'
import json
import re
from pathlib import Path

path = Path(
    "docs/evidence/"
    "authentication-passkey-pilot-validation.json"
)

raw = path.read_text()
lower = raw.lower()

data = json.loads(raw)

assert data["schema_version"] == "1.0"

assert (
    data["evidence_type"]
    == "authentication-passkey-pilot-validation"
)

assert data["phase"] == "feature4d"

policy = data["policy"]

assert policy["state"] == "enabled"
assert policy["self_service_registration_allowed"] is True
assert policy["all_users_targeted"] is True

assert policy["explicit_group_target_count"] == 0
assert policy["exclude_target_count"] == 0

assert policy["passkey_profile_count"] >= 1

assert (
    policy["default_passkey_profile_present"]
    is True
)

assert (
    "deviceBound"
    in policy["supported_passkey_types"]
)

assert (
    "synced"
    in policy["supported_passkey_types"]
)

assert (
    "disabled"
    in policy["attestation_enforcement"]
)

assert policy["key_restrictions_enforced"] is False

pilot = data["pilot"]

assert pilot["account_id"] == "EMPLOYEE_01"
assert pilot["privilege_class"] == "PC3"

assert (
    pilot[
        "authenticated_account_matches_expected"
    ]
    is True
)

assert (
    pilot["phishing_resistant_credential_present"]
    is True
)

assert pilot["target_passkey_type"] == "deviceBound"

assert pilot["total_passkey_count"] >= 1
assert pilot["device_bound_count"] >= 1

assert (
    pilot["microsoft_authenticator_passkey_count"]
    >= 1
)

assert (
    pilot["microsoft_authenticator_mfa_present"]
    is True
)

assert pilot["software_oath_present"] is True

assert (
    "microsoftAuthenticatorAuthenticationMethod"
    in pilot["method_types"]
)

assert (
    "softwareOathAuthenticationMethod"
    in pilot["method_types"]
)

graph = data["graph"]

assert graph["policy"]["requested_scopes"] == [
    "Policy.Read.AuthenticationMethod"
]

assert graph["policy"]["resource_get_count"] == 1
assert graph["policy"]["resource_write_count"] == 0

assert graph["pilot"]["requested_scopes"] == [
    "UserAuthMethod-Passkey.Read",
    "UserAuthenticationMethod.Read",
]

assert graph["pilot"]["resource_get_count"] == 2
assert graph["pilot"]["resource_write_count"] == 0

assert graph["total_get_count"] == 3
assert graph["total_write_count"] == 0

assert all(
    value is False
    for value in
    data["tenant_controls"].values()
)

assert all(
    value is False
    for value in
    data["privacy"].values()
)

for forbidden in (
    "on" + "microsoft.com",
    "access" + "_token",
    "refresh" + "_token",
    "client" + "_secret",
    "temporary" + "_password",
):
    assert forbidden not in lower

assert re.search(
    r"[A-Za-z0-9._%+-]+@"
    r"[A-Za-z0-9.-]+\.[A-Za-z]{2,}",
    raw,
) is None

assert re.search(
    r"\b"
    r"[0-9a-fA-F]{8}-"
    r"[0-9a-fA-F]{4}-"
    r"[0-9a-fA-F]{4}-"
    r"[0-9a-fA-F]{4}-"
    r"[0-9a-fA-F]{12}"
    r"\b",
    raw,
) is None

print("PASS: Feature 4D live evidence validated.")
print("PASS: device-bound passkey verified.")
print("PASS: Microsoft Authenticator provider verified.")
print("PASS: prior MFA and fallback preserved.")
print("PASS: total Graph GETs=3.")
print("PASS: total Graph writes=0.")
print("PASS: privacy boundary validated.")
PY

echo
echo "=================================================="
echo "PASSKEY PILOT VALIDATION PASSED"
echo "=================================================="
