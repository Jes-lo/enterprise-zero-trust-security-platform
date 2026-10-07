#!/usr/bin/env bash

set -euo pipefail

ROOT="$(git rev-parse --show-toplevel)"
cd "$ROOT"

echo "=================================================="
echo "ZERO TRUST ARCHITECTURE VALIDATION"
echo "=================================================="

REQUIRED_FILES=(
  "configs/organization-model.json"
  "docs/architecture/organization-model.md"
  "docs/architecture/zero-trust-architecture.md"
  "docs/security/threat-model.md"
  "docs/security/control-objectives.md"
  "docs/decisions/0001-laboratory-boundary.md"
  "docs/decisions/0002-privileged-identity-separation.md"
)

for file in "${REQUIRED_FILES[@]}"; do
  if [[ ! -f "$file" ]]; then
    echo "FAIL: required architecture artifact missing: $file"
    exit 1
  fi

  echo "PASS: $file"
done

echo
echo "===== JSON VALIDATION ====="

python3 -m json.tool \
  configs/organization-model.json \
  >/dev/null

echo "PASS: organization model is valid JSON."

echo
echo "===== ORGANIZATION CONTRACT ====="

python3 - <<'PY'
import json
from pathlib import Path

data = json.loads(Path("configs/organization-model.json").read_text())

assert data["schema_version"] == "1.0"
assert data["organization"]["code"] == "ZT-LAB"
assert data["organization"]["environment_type"] == "non-production"
assert data["organization"]["data_classification"] == "synthetic-only"

departments = {entry["code"] for entry in data["departments"]}
personas = {entry["code"] for entry in data["identity_personas"]}
privileges = {entry["code"] for entry in data["privilege_classes"]}

required_departments = {
    "EXEC",
    "FIN",
    "HR",
    "SALES",
    "ENG",
    "ITOPS",
    "SEC",
}

required_personas = {
    "EMPLOYEE",
    "DEVELOPER",
    "IT_OPERATOR",
    "SECURITY_ENGINEER",
    "PRIVILEGED_ADMIN",
    "EXECUTIVE",
    "CONTRACTOR",
    "GUEST",
    "WORKLOAD",
    "EMERGENCY_ADMIN",
}

required_privileges = {
    "PC0",
    "PC1",
    "PC2",
    "PC3",
}

assert departments == required_departments
assert personas == required_personas
assert privileges == required_privileges

print("PASS: organization contract validated.")
PY

echo
echo "===== CONTROL IDENTIFIERS ====="

for prefix in \
  ZT-ID \
  ZT-AUTH \
  ZT-AZ \
  ZT-ACCESS \
  ZT-ENDPOINT \
  ZT-APP \
  ZT-MON \
  ZT-TEST
do
  if ! grep -q "$prefix-" docs/security/control-objectives.md; then
    echo "FAIL: control family missing: $prefix"
    exit 1
  fi

  echo "PASS: $prefix"
done

echo
echo "===== ADR STATUS ====="

for adr in \
  docs/decisions/0001-laboratory-boundary.md \
  docs/decisions/0002-privileged-identity-separation.md
do
  if ! grep -Fq "Accepted" "$adr"; then
    echo "FAIL: accepted ADR status missing: $adr"
    exit 1
  fi

  echo "PASS: $adr"
done

echo
echo "=================================================="
echo "ZERO TRUST ARCHITECTURE VALIDATION PASSED"
echo "=================================================="
