#!/usr/bin/env bash
set -euo pipefail

ROOT="$(
  cd "$(dirname "${BASH_SOURCE[0]}")/.." &&
  pwd
)"

cd "$ROOT"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

cp configs/enterprise-application-governance.json \
  "$TMP/config.json"

cp policies/apps/enterprise-application-permission-baseline.yaml \
  "$TMP/policy.yaml"

cp docs/evidence/feature-9b-enterprise-application-inventory-validation.json \
  "$TMP/evidence.json"

expect_rejected() {
  local name="$1"
  shift

  set +e
  "$@" >"$TMP/$name.out" 2>&1
  local rc=$?
  set -e

  if [[ "$rc" -eq 0 ]]; then
    echo "FAIL: closure validator accepted fixture: $name"
    cat "$TMP/$name.out"
    exit 1
  fi

  echo "PASS: closure validator rejected fixture: $name"
}

echo "===== FEATURE 9 CLOSURE BASELINE ====="

./scripts/validate-feature-9-closure.sh

echo
echo "===== FEATURE 9 CLOSURE ADVERSARIAL ====="

for key in \
  creation_authorized \
  service_principal_creation_authorized \
  application_readwrite_all_authorized \
  directory_readwrite_all_authorized \
  new_admin_role_authorized \
  credential_creation_authorized \
  additional_consent_authorized
do
  target="$TMP/${key}.json"

  python3 - \
    "$TMP/config.json" \
    "$target" \
    "$key" <<'PY'
import json
import sys

source, target, key = sys.argv[1:4]

with open(source, encoding="utf-8") as handle:
    data = json.load(handle)

data["feature9_closure"]["synthetic_application"][key] = True

with open(target, "w", encoding="utf-8") as handle:
    json.dump(data, handle, indent=2)
    handle.write("\n")
PY

  expect_rejected \
    "$key" \
    env FEATURE9CLOSE_CONFIG_FILE="$target" \
    ./scripts/validate-feature-9-closure.sh
done

python3 - \
  "$TMP/evidence.json" \
  "$TMP/tenant-owned-app.json" <<'PY'
import json
import sys

source, target = sys.argv[1:3]

with open(source, encoding="utf-8") as handle:
    data = json.load(handle)

data["summary"]["tenant_owned_service_principals"] = 1

with open(target, "w", encoding="utf-8") as handle:
    json.dump(data, handle, indent=2)
    handle.write("\n")
PY

expect_rejected \
  "tenant-owned-state-drift" \
  env FEATURE9CLOSE_EVIDENCE_FILE="$TMP/tenant-owned-app.json" \
  ./scripts/validate-feature-9-closure.sh

sed \
  's/application_readwrite_all_authorized: false/application_readwrite_all_authorized: true/' \
  "$TMP/policy.yaml" \
  > "$TMP/policy-write-enabled.yaml"

expect_rejected \
  "policy-write-permission-expansion" \
  env FEATURE9CLOSE_POLICY_FILE="$TMP/policy-write-enabled.yaml" \
  ./scripts/validate-feature-9-closure.sh

echo
echo "FEATURE_9_CLOSURE_ADVERSARIAL_TESTS=PASS"
