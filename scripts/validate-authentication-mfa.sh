#!/usr/bin/env bash

set -euo pipefail

echo "=================================================="
echo "AUTHENTICATION & MFA FOUNDATION VALIDATION"
echo "=================================================="

CONFIG="configs/authentication-mfa.json"
COLLECTOR="automation/powershell/Get-AuthenticationMfaReadiness.ps1"

ARCH_DOC="docs/architecture/authentication-mfa-foundation.md"
STANDARD_DOC="docs/security/authentication-method-standard.md"
ADR="docs/decisions/0005-staged-authentication-mfa-rollout.md"
EVIDENCE="docs/evidence/authentication-mfa-readiness.json"

for path in \
  "$CONFIG" \
  "$COLLECTOR" \
  "$ARCH_DOC" \
  "$STANDARD_DOC" \
  "$ADR"
do
  [[ -s "$path" ]] || {
    echo "FAIL: missing Feature 4A artifact: $path"
    exit 1
  }

  echo "PASS: $path"
done

echo
echo "===== JSON CONTRACT ====="

python3 - <<'PY'
import json
from pathlib import Path

config = json.loads(
    Path(
        "configs/authentication-mfa.json"
    ).read_text()
)

assert config["schema_version"] == "1.0"

assert (
    config["feature"]
    == "authentication-mfa-foundation"
)

assert config["control_family"] == "ZT-AUTH"

readiness = config["readiness"]

assert readiness["mode"] == "read_only"

assert readiness["graph_scopes"] == [
    "Policy.Read.All"
]

assert readiness["expected_resource_get_count"] == 2

assert (
    readiness["resource_writes_allowed"]
    is False
)

assert readiness["graph_requests"] == [
    {
        "method": "GET",
        "resource": (
            "/policies/authenticationMethodsPolicy"
        ),
    },
    {
        "method": "GET",
        "resource": (
            "/policies/"
            "identitySecurityDefaultsEnforcementPolicy"
        ),
    },
]

assert (
    config["security_defaults"]
    ["disable_in_feature4a"]
    is False
)

assert (
    config["security_defaults"]
    ["preserve_until_replacement_controls_are_validated"]
    is True
)

safety = config["safety"]

assert all(
    safety[key] is True
    for key in (
        "no_authentication_policy_writes_in_feature4a",
        "no_security_defaults_changes_in_feature4a",
        "no_conditional_access_changes_in_feature4a",
        "no_role_assignment_changes_in_feature4a",
        "no_user_authentication_method_deletion_in_feature4a",
    )
)

boundaries = config["feature_boundaries"]

assert (
    boundaries["conditional_access_enforcement"]
    == "feature6"
)

assert (
    boundaries["privileged_role_assignment"]
    == "feature5"
)

print("PASS: Feature 4A contract validated.")
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
    "automation/powershell/Get-AuthenticationMfaReadiness.ps1",
    [ref]$tokens,
    [ref]$errors
) | Out-Null

if ($errors.Count -gt 0) {
    foreach ($errorItem in $errors) {
        Write-Host (
            "FAIL line=" +
            $errorItem.Extent.StartLineNumber +
            " column=" +
            $errorItem.Extent.StartColumnNumber +
            " message=" +
            $errorItem.Message
        )
    }

    exit 1
}

Write-Host "PASS: PowerShell syntax valid."
'

echo
echo "===== READ-ONLY GRAPH SURFACE ====="

python3 - <<'PY'
from pathlib import Path

text = Path(
    "automation/powershell/"
    "Get-AuthenticationMfaReadiness.ps1"
).read_text()

required = [
    '"Policy.Read.All"',
    "-Method GET",
    "policies/authenticationMethodsPolicy",
    "identitySecurityDefaultsEnforcementPolicy",
    "graph_resource_write_count=0",
    "-UseDeviceAuthentication",
]

for marker in required:
    assert marker in text, marker

for forbidden in (
    "-Method POST",
    "-Method PATCH",
    "-Method PUT",
    "-Method DELETE",
):
    assert forbidden not in text, forbidden

assert (
    text.count(
        "Invoke-ReadOnlyGraphRequest `"
    )
    == 2
)

print("PASS: collector Graph resource surface is GET-only.")
print("PASS: exactly two read-only resource calls modeled.")
PY

echo
echo "===== FEATURE BOUNDARIES ====="

python3 - <<'PY_BOUNDARIES'
from pathlib import Path


def normalized(path):
    return " ".join(
        Path(path)
        .read_text()
        .lower()
        .split()
    )


architecture = normalized(
    "docs/architecture/"
    "authentication-mfa-foundation.md"
)

standard = normalized(
    "docs/security/"
    "authentication-method-standard.md"
)

adr = normalized(
    "docs/decisions/"
    "0005-staged-authentication-mfa-rollout.md"
)

required_architecture = (
    "feature 4",
    "conditional access",
    "feature 6",
    "privileged role",
)

for phrase in required_architecture:
    if phrase not in architecture:
        raise SystemExit(
            "FAIL: architecture boundary missing: "
            + phrase
        )

required_standard = (
    "feature 4a",
    "read-only",
    "conditional access",
    "security defaults",
)

for phrase in required_standard:
    if phrase not in standard:
        raise SystemExit(
            "FAIL: authentication standard boundary missing: "
            + phrase
        )

required_adr = (
    "feature 4a",
    "security defaults",
    "read operations",
    "conditional access",
)

for phrase in required_adr:
    if phrase not in adr:
        raise SystemExit(
            "FAIL: ADR boundary missing: "
            + phrase
        )

print(
    "PASS: architecture keeps Conditional Access "
    "outside Feature 4."
)

print(
    "PASS: standard requires Feature 4A "
    "to remain read-only."
)

print(
    "PASS: ADR preserves Security Defaults "
    "during Feature 4A."
)
PY_BOUNDARIES

echo "PASS: Feature 4/5/6 boundaries preserved."

if [[ ! -e "$EVIDENCE" ]]; then
  echo
  echo "INFO: sanitized live readiness evidence not present yet."
  echo "INFO: pre-live validation stops before evidence assertions."
  echo
  echo "=================================================="
  echo "AUTHENTICATION & MFA PRE-LIVE VALIDATION PASSED"
  echo "=================================================="
  exit 0
fi

echo
echo "===== SANITIZED LIVE EVIDENCE ====="

python3 - <<'PY'
import json
import re
from pathlib import Path

path = Path(
    "docs/evidence/"
    "authentication-mfa-readiness.json"
)

raw = path.read_text()
lower = raw.lower()
data = json.loads(raw)

assert data["schema_version"] == "1.0"

assert (
    data["evidence_type"]
    == "authentication-mfa-readiness"
)

assert (
    data["feature"]
    == "authentication-mfa-foundation"
)

assert data["collection_mode"] == "read_only"

graph = data["graph"]

assert graph["requested_scopes"] == [
    "Policy.Read.All"
]

assert graph["resource_get_count"] == 2
assert graph["resource_write_count"] == 0

assert (
    data["security_defaults"]["modified"]
    is False
)

assert isinstance(
    data["security_defaults"]["enabled"],
    bool,
)

policy = data["authentication_methods_policy"]

methods = policy["methods"]

assert isinstance(methods, list)
assert len(methods) > 0

assert (
    policy["method_configuration_count"]
    == len(methods)
)

for method in methods:
    assert set(method) == {
        "configuration_type",
        "state",
        "include_target_count",
        "exclude_target_count",
    }

    assert isinstance(
        method["configuration_type"],
        str,
    )

    assert method["configuration_type"]

    assert isinstance(
        method["state"],
        str,
    )

    assert method["state"]

    assert isinstance(
        method["include_target_count"],
        int,
    )

    assert isinstance(
        method["exclude_target_count"],
        int,
    )

    assert method["include_target_count"] >= 0
    assert method["exclude_target_count"] >= 0

assert all(
    value is False
    for value in
    data["feature4a_assertions"].values()
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

print("PASS: sanitized readiness evidence validated.")

print(
    "PASS: authentication_method_configurations=" +
    str(len(methods))
)

print(
    "PASS: security_defaults_enabled=" +
    str(
        data["security_defaults"]["enabled"]
    )
)
PY

echo
echo "===== PRIVACY BOUNDARY ====="

python3 - <<'PY'
import re
from pathlib import Path

tracked = [
    Path("configs/authentication-mfa.json"),
    Path(
        "docs/architecture/"
        "authentication-mfa-foundation.md"
    ),
    Path(
        "docs/security/"
        "authentication-method-standard.md"
    ),
    Path(
        "docs/decisions/"
        "0005-staged-authentication-mfa-rollout.md"
    ),
    Path(
        "docs/evidence/"
        "authentication-mfa-readiness.json"
    ),
]

raw = "\n".join(
    path.read_text()
    for path in tracked
)

assert "on" + "microsoft.com" not in raw.lower()

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

print("PASS: no tenant identifiers published.")
PY

echo
echo "=================================================="
echo "AUTHENTICATION & MFA FOUNDATION VALIDATION PASSED"
echo "=================================================="
