#!/usr/bin/env bash

set -euo pipefail

ROOT="$(git rev-parse --show-toplevel)"
cd "$ROOT"

echo "=================================================="
echo "IDENTITY FOUNDATION VALIDATION"
echo "=================================================="

REQUIRED_FILES=(
  "configs/identity-foundation.json"
  "docs/architecture/identity-foundation.md"
  "docs/security/identity-naming-standard.md"
  "docs/evidence/identity-foundation-evidence.md"
  "docs/decisions/0004-shared-portfolio-lab-identity-model.md"
)

for file in "${REQUIRED_FILES[@]}"; do
  if [[ ! -s "$file" ]]; then
    echo "FAIL: missing or empty $file"
    exit 1
  fi

  echo "PASS: $file"
done

echo
echo "===== JSON CONTRACT ====="

python3 - <<'PY_CONTRACT'
import json
import re
from pathlib import Path

path = Path("configs/identity-foundation.json")
text = path.read_text()
data = json.loads(text)

assert data["schema_version"] == "1.0"

model = data["model"]

assert model["project_internal_code"] == "ZT-LAB"
assert model["shared_tenant_resource_prefix"] == "PLAB"
assert model["shared_tenant_display_name"] == "Portfolio Project Lab"
assert model["environment_type"] == "non-production"
assert model["data_classification"] == "synthetic-only"

principles = data["principles"]

required_false = (
    "personal_identifiers_allowed",
    "real_customer_data_allowed",
    "real_employer_data_allowed",
    "passwords_allowed_in_repository",
    "tenant_domain_allowed_in_repository",
    "user_principal_names_allowed_in_repository",
)

for key in required_false:
    assert principles[key] is False, key

assert principles["standard_and_privileged_identity_separation"] is True
assert principles["emergency_accounts_are_cloud_only"] is True

accounts = data["accounts"]
groups = data["groups"]

account_ids = [item["id"] for item in accounts]
aliases = [item["alias"] for item in accounts]
display_names = [item["display_name"] for item in accounts]

assert len(account_ids) == 14
assert len(account_ids) == len(set(account_ids))
assert len(aliases) == len(set(aliases))
assert len(display_names) == len(set(display_names))

expected_accounts = {
    "BOOTSTRAP_ADMIN",
    "PRIVILEGED_ADMIN_01",
    "EMPLOYEE_01",
    "FINANCE_01",
    "SALES_01",
    "DEVELOPER_01",
    "IT_OPERATOR_01",
    "SECURITY_ENGINEER_01",
    "EXECUTIVE_01",
    "CONTRACTOR_01",
    "EMERGENCY_ADMIN_01",
    "EMERGENCY_ADMIN_02",
    "GUEST_01",
    "WORKLOAD_AUTOMATION_01",
}

assert set(account_ids) == expected_accounts

by_id = {
    item["id"]: item
    for item in accounts
}

assert by_id["BOOTSTRAP_ADMIN"]["live_state"] == "existing"
assert by_id["BOOTSTRAP_ADMIN"]["live_creation"] is False
assert by_id["BOOTSTRAP_ADMIN"]["alias"] == "bootstrapadmin"

assert by_id["PRIVILEGED_ADMIN_01"]["live_state"] == "deferred"
assert by_id["PRIVILEGED_ADMIN_01"]["live_creation"] is False
assert (
    by_id["PRIVILEGED_ADMIN_01"]["license_policy"]
    == "deferred-to-feature-5"
)

business_premium = {
    item["id"]
    for item in accounts
    if item["live_creation"] is True
    and item["license_policy"] == "business-premium"
}

assert business_premium == {
    "EMPLOYEE_01",
    "FINANCE_01",
    "SALES_01",
    "DEVELOPER_01",
    "IT_OPERATOR_01",
    "SECURITY_ENGINEER_01",
    "EXECUTIVE_01",
    "CONTRACTOR_01",
}

emergency = {
    item["id"]
    for item in accounts
    if item["persona"] == "EMERGENCY_ADMIN"
}

assert emergency == {
    "EMERGENCY_ADMIN_01",
    "EMERGENCY_ADMIN_02",
}

for identifier in emergency:
    item = by_id[identifier]

    assert item["cloud_only"] is True
    assert item["license_policy"] == "unlicensed"
    assert item["privilege_class"] == "PC0"

assert set(data["deferred_identity_ids"]) == {
    "PRIVILEGED_ADMIN_01",
    "GUEST_01",
    "WORKLOAD_AUTOMATION_01",
}

group_ids = [item["id"] for item in groups]
group_names = [item["display_name"] for item in groups]
mail_nicknames = [item["mail_nickname"] for item in groups]

assert len(groups) == 11
assert len(group_ids) == len(set(group_ids))
assert len(group_names) == len(set(group_names))
assert len(mail_nicknames) == len(set(mail_nicknames))

known_accounts = set(account_ids)

for group in groups:
    assert group["display_name"].startswith("PLAB-")
    assert group["group_type"] == "security"
    assert group["membership_type"] == "assigned"

    unknown = set(group["members"]) - known_accounts

    assert not unknown, (
        f"{group['id']} has unknown members: {sorted(unknown)}"
    )

workforce = next(
    item
    for item in groups
    if item["id"] == "WORKFORCE"
)

assert set(workforce["members"]) == business_premium

for excluded in (
    "BOOTSTRAP_ADMIN",
    "PRIVILEGED_ADMIN_01",
    "EMERGENCY_ADMIN_01",
    "EMERGENCY_ADMIN_02",
    "GUEST_01",
    "WORKLOAD_AUTOMATION_01",
):
    assert excluded not in workforce["members"]

for identifier, owner in (
    ("CA_PILOT", 6),
    ("DEVICE_PILOT", 8),
):
    group = next(
        item
        for item in groups
        if item["id"] == identifier
    )

    assert group["members"] == []
    assert group["membership_managed_in_feature"] == owner

required_departments = {
    "EXEC",
    "FIN",
    "HR",
    "SALES",
    "ENG",
    "ITOPS",
    "SEC",
}

represented_departments = {
    item["department"]
    for item in accounts
    if item["department"] != "EXTERNAL"
    and item["live_state"] != "deferred"
}

assert required_departments <= represented_departments

if re.search(
    r"onmicrosoft\.com",
    text,
    flags=re.IGNORECASE,
):
    raise AssertionError("tenant domain found in identity contract")

if re.search(
    r"@[A-Za-z0-9._+-]+\.[A-Za-z]{2,}",
    text,
):
    raise AssertionError("email-like value found in identity contract")

prohibited_keys = (
    '"password"',
    '"temporary_password"',
    '"tenant_id"',
    '"object_id"',
    '"client_secret"',
)

lower = text.lower()

for key in prohibited_keys:
    assert key not in lower, key

print("PASS: identity foundation contract validated.")
print("PASS: 14 identities modeled.")
print("PASS: 8 Business Premium workforce identities planned.")
print("PASS: 2 emergency identities cloud-only and unlicensed.")
print("PASS: 11 security groups validated.")
print("PASS: future-feature pilot memberships remain empty.")
PY_CONTRACT

echo
echo "===== ORGANIZATION MODEL ALIGNMENT ====="

python3 - <<'PY_ALIGNMENT'
import json
from pathlib import Path

organization = json.loads(
    Path("configs/organization-model.json").read_text()
)

identity = json.loads(
    Path("configs/identity-foundation.json").read_text()
)

org_text = json.dumps(organization)

for account in identity["accounts"]:
    persona = account["persona"]

    assert persona in org_text, (
        f"persona missing from organization model: {persona}"
    )

    department = account["department"]

    if department != "EXTERNAL":
        assert department in org_text, (
            f"department missing from organization model: {department}"
        )

    privilege = account["privilege_class"]

    assert privilege in org_text, (
        f"privilege class missing from organization model: {privilege}"
    )

print("PASS: personas, departments and privilege classes align.")
PY_ALIGNMENT

echo
echo "===== REPOSITORY PRIVACY BOUNDARY ====="

FILES=(
  "configs/identity-foundation.json"
  "docs/architecture/identity-foundation.md"
  "docs/security/identity-naming-standard.md"
  "docs/evidence/identity-foundation-evidence.md"
  "docs/decisions/0004-shared-portfolio-lab-identity-model.md"
)

if grep -Ein \
    'onmicrosoft\.com|@[A-Za-z0-9._+-]+\.[A-Za-z]{2,}' \
    "${FILES[@]}"; then

  echo "FAIL: tenant domain or complete email/UPN detected."
  exit 1
fi

echo "PASS: no tenant domain or complete UPN published."

echo
echo "===== SHARED TENANT NAMING ====="

for phrase in \
  "Portfolio Lab" \
  "PLAB-" \
  "bootstrapadmin" \
  "privilegedadmin01" \
  "emergencyadmin01" \
  "emergencyadmin02"
do
  if ! grep -Fq \
      "$phrase" \
      docs/security/identity-naming-standard.md; then

    echo "FAIL: naming rule missing: $phrase"
    exit 1
  fi
done

echo "PASS: naming standard validated."

echo
echo "===== FEATURE BOUNDARIES ====="

for phrase in \
  "Feature 4" \
  "Feature 5" \
  "Feature 6" \
  "Feature 7"
do
  if ! grep -Fq \
      "$phrase" \
      docs/architecture/identity-foundation.md; then

    echo "FAIL: feature boundary missing: $phrase"
    exit 1
  fi
done

echo "PASS: identity/security feature boundaries preserved."

echo
echo "===== ADR STATUS ====="

if ! grep -Fq \
    "Status: Accepted" \
    docs/decisions/0004-shared-portfolio-lab-identity-model.md; then

  echo "FAIL: ADR-0004 is not accepted."
  exit 1
fi

echo "PASS: ADR-0004 accepted."

echo
echo "=================================================="
echo "IDENTITY FOUNDATION VALIDATION PASSED"
echo "=================================================="
