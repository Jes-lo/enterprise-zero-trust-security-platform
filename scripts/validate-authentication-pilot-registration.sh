#!/usr/bin/env bash

set -euo pipefail

echo "=================================================="
echo "AUTHENTICATOR PILOT REGISTRATION VALIDATION"
echo "=================================================="

CONFIG="configs/authentication-mfa.json"

VERIFIER="automation/powershell/Test-AuthenticationPilotSelfMethods.ps1"

RUNBOOK="docs/security/authentication-pilot-registration-runbook.md"

EVIDENCE="docs/evidence/authentication-pilot-registration-validation.json"

for path in \
  "$CONFIG" \
  "$VERIFIER" \
  "$RUNBOOK"
do
  [[ -s "$path" ]] || {
    echo "FAIL: missing Feature 4C artifact: $path"
    exit 1
  }

  echo "PASS: $path"
done

echo
echo "===== FEATURE 4C CONTRACT ====="

python3 - <<'PY'
import json
from pathlib import Path

data = json.loads(
    Path(
        "configs/authentication-mfa.json"
    ).read_text()
)

pilot = data["pilot_registration"]

assert pilot["phase"] == "feature4c"
assert pilot["mode"] == "user_interactive"
assert pilot["pilot_account_id"] == "EMPLOYEE_01"
assert pilot["pilot_privilege_class"] == "PC3"

assert (
    pilot["target_method"]
    == "microsoft_authenticator"
)

assert pilot["policy_change_required"] is False

for key in (
    "security_defaults_change_allowed",
    "authentication_policy_change_allowed",
    "conditional_access_change_allowed",
    "emergency_identity_use_allowed",
):
    assert pilot[key] is False, key

verification = pilot["verification"]

assert (
    verification["mode"]
    == "signed_in_user_self_read"
)

assert verification["delegated_scopes"] == [
    "UserAuthenticationMethod.Read"
]

assert (
    verification["resource"]
    == "/me/authentication/methods"
)

assert (
    verification["resource_writes_allowed"]
    is False
)

print("PASS: Feature 4C contract validated.")
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
    "automation/powershell/Test-AuthenticationPilotSelfMethods.ps1",
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

Write-Host "PASS: Feature 4C verifier syntax valid."
'

echo
echo "===== LEAST-PRIVILEGE SELF READ ====="

python3 - <<'PY'
from pathlib import Path

text = Path(
    "automation/powershell/"
    "Test-AuthenticationPilotSelfMethods.ps1"
).read_text()

required = (
    '"UserAuthenticationMethod.Read"',
    "me/authentication/methods",
    "-UseDeviceAuthentication",
    "-Method GET",
    "Wrong account authenticated",
)

for marker in required:
    assert marker in text, marker

for forbidden in (
    "UserAuthenticationMethod.Read.All",
    "UserAuthenticationMethod.ReadWrite",
    "UserAuthenticationMethod.ReadWrite.All",
    "-Method POST",
    "-Method PATCH",
    "-Method PUT",
    "-Method DELETE",
):
    assert forbidden not in text, forbidden

print("PASS: verifier is signed-user self-read only.")
print("PASS: no Graph write method present.")
PY

if [[ ! -e "$EVIDENCE" ]]; then
  echo
  echo "INFO: live pilot-registration evidence not present yet."
  echo "PASS: Feature 4C pre-registration validation complete."
  exit 0
fi

echo
echo "===== LIVE REGISTRATION EVIDENCE ====="

python3 - <<'PY'
import json
import re
from pathlib import Path

path = Path(
    "docs/evidence/"
    "authentication-pilot-registration-validation.json"
)

raw = path.read_text()
lower = raw.lower()

data = json.loads(raw)

assert data["schema_version"] == "1.0"

assert (
    data["evidence_type"]
    == "authentication-pilot-registration-validation"
)

assert data["phase"] == "feature4c"

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
    pilot["microsoft_authenticator_registered"]
    is True
)

assert (
    pilot["authentication_method_count"]
    >= 1
)

assert (
    "microsoftAuthenticatorAuthenticationMethod"
    in pilot["method_types"]
)

graph = data["graph"]

assert graph["requested_scopes"] == [
    "UserAuthenticationMethod.Read"
]

assert (
    graph["resource"]
    == "/me/authentication/methods"
)

assert graph["resource_get_count"] == 1
assert graph["resource_write_count"] == 0

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

print("PASS: Feature 4C live evidence validated.")
print("PASS: Microsoft Authenticator registered.")
print("PASS: Graph GETs=1.")
print("PASS: Graph writes=0.")
PY

echo
echo "=================================================="
echo "AUTHENTICATOR PILOT REGISTRATION VALIDATION PASSED"
echo "=================================================="
