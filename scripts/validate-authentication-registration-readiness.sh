#!/usr/bin/env bash

set -euo pipefail

echo "=================================================="
echo "AUTHENTICATION REGISTRATION READINESS VALIDATION"
echo "=================================================="

CONFIG="configs/authentication-mfa.json"
IDENTITY="configs/identity-foundation.json"

COLLECTOR="automation/powershell/Get-AuthenticationRegistrationReadiness.ps1"
EVIDENCE="docs/evidence/authentication-registration-readiness.json"
PILOT_PLAN="docs/security/authentication-pilot-plan.md"

for path in \
  "$CONFIG" \
  "$IDENTITY" \
  "$COLLECTOR"
do
  [[ -s "$path" ]] || {
    echo "FAIL: missing required Feature 4B artifact: $path"
    exit 1
  }

  echo "PASS: $path"
done

echo
echo "===== CONTRACT ====="

python3 - <<'PY'
import json
from pathlib import Path

data = json.loads(
    Path(
        "configs/authentication-mfa.json"
    ).read_text()
)

registration = data["registration_readiness"]

assert registration["phase"] == "feature4b"
assert registration["mode"] == "read_only"

assert registration["graph_scopes"] == [
    "AuditLog.Read.All",
    "Policy.Read.AuthenticationMethod",
]

assert (
    registration[
        "expected_managed_workforce_count"
    ]
    == 8
)

assert (
    registration[
        "disabled_emergency_accounts_excluded"
    ]
    is True
)

assert (
    registration[
        "expected_disabled_emergency_count"
    ]
    == 2
)

assert (
    registration["resource_writes_allowed"]
    is False
)

pilot = data["controlled_pilot"]

assert (
    pilot["phase"]
    == "feature4b-plan-only"
)

assert (
    pilot["pilot_account_id"]
    == "EMPLOYEE_01"
)

assert (
    pilot["pilot_privilege_class"]
    == "PC3"
)

for key in (
    "authentication_policy_write_allowed",
    "user_method_write_allowed",
    "security_defaults_change_allowed",
    "conditional_access_change_allowed",
    "emergency_identity_use_allowed",
):
    assert pilot[key] is False, key

assert (
    pilot[
        "next_checkpoint_requires_readiness_review"
    ]
    is True
)

print("PASS: Feature 4B contract validated.")
PY

echo
echo "===== MANAGED POPULATION ====="

python3 - <<'PY'
import json
from pathlib import Path

data = json.loads(
    Path(
        "configs/identity-foundation.json"
    ).read_text()
)

workforce = [
    account
    for account in data["accounts"]
    if (
        account["live_creation"] is True
        and
        account["license_policy"]
        == "business-premium"
    )
]

emergency = [
    account
    for account in data["accounts"]
    if account["persona"] == "EMERGENCY_ADMIN"
]

assert len(workforce) == 8
assert len(emergency) == 2

assert next(
    account
    for account in workforce
    if account["id"] == "EMPLOYEE_01"
)["privilege_class"] == "PC3"

print("PASS: workforce denominator=8.")
print("PASS: disabled emergency exclusion model=2.")
print("PASS: pilot candidate=EMPLOYEE_01 / PC3.")
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
    "automation/powershell/Get-AuthenticationRegistrationReadiness.ps1",
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

Write-Host "PASS: PowerShell syntax valid."
'

echo
echo "===== READ-ONLY GRAPH SURFACE ====="

python3 - <<'PY'
from pathlib import Path

text = Path(
    "automation/powershell/"
    "Get-AuthenticationRegistrationReadiness.ps1"
).read_text()

required = [
    '"AuditLog.Read.All"',
    '"Policy.Read.AuthenticationMethod"',
    "-Method GET",
    "authenticationMethodsPolicy",
    "userRegistrationDetails",
    "-UseDeviceAuthentication",
]

for marker in required:
    assert marker in text, marker

for method in (
    "POST",
    "PATCH",
    "PUT",
    "DELETE",
):
    assert f"-Method {method}" not in text, method

print("PASS: Feature 4B Graph surface is GET-only.")
PY

if [[ ! -e "$EVIDENCE" ]]; then
  echo
  echo "INFO: Feature 4B live evidence not present yet."
  echo "PASS: pre-live Feature 4B validation complete."
  exit 0
fi

echo
echo "===== LIVE SANITIZED EVIDENCE ====="

python3 - <<'PY'
import json
import re
from pathlib import Path

path = Path(
    "docs/evidence/"
    "authentication-registration-readiness.json"
)

raw = path.read_text()
lower = raw.lower()
data = json.loads(raw)

assert data["schema_version"] == "1.0"

assert (
    data["evidence_type"]
    == "authentication-registration-readiness"
)

assert data["phase"] == "feature4b"
assert data["collection_mode"] == "read_only"

assert data["graph"]["requested_scopes"] == [
    "AuditLog.Read.All",
    "Policy.Read.AuthenticationMethod",
]

assert data["graph"]["resource_get_count"] >= 2
assert data["graph"]["resource_write_count"] == 0

population = data["population"]

assert population["managed_workforce_expected"] == 8
assert 0 <= population["managed_workforce_report_present"] <= 8
assert population["disabled_emergency_excluded"] == 2

workforce = data["managed_workforce"]

assert len(workforce) == 8

ids = [
    item["account_id"]
    for item in workforce
]

assert len(ids) == len(set(ids))

assert set(ids) == {
    "EMPLOYEE_01",
    "FINANCE_01",
    "SALES_01",
    "DEVELOPER_01",
    "IT_OPERATOR_01",
    "SECURITY_ENGINEER_01",
    "EXECUTIVE_01",
    "CONTRACTOR_01",
}

for item in workforce:
    assert item["privilege_class"] in {
        "PC2",
        "PC3",
    }

    assert isinstance(
        item["report_present"],
        bool,
    )

    assert isinstance(
        item["methods_registered"],
        list,
    )

    assert isinstance(
        item["system_preferred_methods"],
        list,
    )

targeting = data[
    "authentication_method_targeting"
]

assert isinstance(targeting, list)
assert len(targeting) > 0

for item in targeting:
    assert isinstance(
        item["include_target_count"],
        int,
    )

    assert isinstance(
        item["exclude_target_count"],
        int,
    )

    for scope_class in (
        item[
            "include_target_scope_classes"
        ]
    ):
        assert scope_class in {
            "all_users",
            "object_reference",
            "named_reference",
            "missing",
        }

pilot = data["pilot"]

assert pilot["account_id"] == "EMPLOYEE_01"
assert pilot["privilege_class"] == "PC3"

assert pilot["readiness_status"] in {
    "blocked-registration-report-missing",
    "ready-for-existing-registration-validation",
    "ready-for-controlled-strong-method-registration",
}

assert all(
    value is False
    for value in
    data["feature4b_assertions"].values()
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

print("PASS: Feature 4B evidence validated.")
print(
    "PASS: managed workforce report present=" +
    str(
        population[
            "managed_workforce_report_present"
        ]
    )
    + "/8"
)
print(
    "PASS: MFA registered=" +
    str(
        data[
            "readiness_summary"
        ]["mfa_registered"]
    )
    + "/8"
)
PY

[[ -s "$PILOT_PLAN" ]] || {
  echo "FAIL: pilot plan missing after live collection."
  exit 1
}

echo "PASS: controlled pilot plan exists."

echo
echo "=================================================="
echo "AUTHENTICATION REGISTRATION READINESS PASSED"
echo "=================================================="
