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

cp automation/powershell/Get-EnterpriseApplicationInventory.ps1 \
  "$TMP/stage1.ps1"

cp automation/powershell/Get-DelegatedPermissionGrantInventory.ps1 \
  "$TMP/stage2.ps1"

cp configs/authentication-mfa.json \
  "$TMP/auth.json"

expect_rejected() {
  local name="$1"
  shift

  set +e
  "$@" >"$TMP/$name.out" 2>&1
  local rc=$?
  set -e

  if [[ "$rc" -eq 0 ]]; then
    echo "FAIL: validator accepted adversarial fixture: $name"
    cat "$TMP/$name.out"
    exit 1
  fi

  echo "PASS: validator rejected adversarial fixture: $name"
}

echo "===== FEATURE 9 BASELINE VALIDATION ====="

./scripts/validate-feature-9.sh

echo
echo "===== FEATURE 9 ADVERSARIAL VALIDATION ====="

python3 - "$TMP/config.json" "$TMP/write-enabled.json" <<'PY'
import json
import sys

source, target = sys.argv[1:3]

with open(source, encoding="utf-8") as handle:
    data = json.load(handle)

data["authorization"]["tenant_writes"] = True

with open(target, "w", encoding="utf-8") as handle:
    json.dump(data, handle, indent=2)
    handle.write("\n")
PY

expect_rejected \
  "tenant-write-enabled" \
  env FEATURE9_CONFIG_FILE="$TMP/write-enabled.json" \
  ./scripts/validate-feature-9.sh

python3 - "$TMP/config.json" "$TMP/admin-consent.json" <<'PY'
import json
import sys

source, target = sys.argv[1:3]

with open(source, encoding="utf-8") as handle:
    data = json.load(handle)

data["authorization"]["admin_consent"] = True

with open(target, "w", encoding="utf-8") as handle:
    json.dump(data, handle, indent=2)
    handle.write("\n")
PY

expect_rejected \
  "admin-consent-enabled" \
  env FEATURE9_CONFIG_FILE="$TMP/admin-consent.json" \
  ./scripts/validate-feature-9.sh

python3 - "$TMP/config.json" "$TMP/app-create.json" <<'PY'
import json
import sys

source, target = sys.argv[1:3]

with open(source, encoding="utf-8") as handle:
    data = json.load(handle)

data["authorization"]["application_registration_creation"] = True

with open(target, "w", encoding="utf-8") as handle:
    json.dump(data, handle, indent=2)
    handle.write("\n")
PY

expect_rejected \
  "application-creation-enabled" \
  env FEATURE9_CONFIG_FILE="$TMP/app-create.json" \
  ./scripts/validate-feature-9.sh

python3 - "$TMP/config.json" "$TMP/write-scope.json" <<'PY'
import json
import sys

source, target = sys.argv[1:3]

with open(source, encoding="utf-8") as handle:
    data = json.load(handle)

data["graph_discovery"]["stage1"]["scope"] = "Directory.ReadWrite.All"

with open(target, "w", encoding="utf-8") as handle:
    json.dump(data, handle, indent=2)
    handle.write("\n")
PY

expect_rejected \
  "write-capable-stage1-scope" \
  env FEATURE9_CONFIG_FILE="$TMP/write-scope.json" \
  ./scripts/validate-feature-9.sh

python3 - "$TMP/config.json" "$TMP/stage1-authorized.json" <<'PY'
import json
import sys

source, target = sys.argv[1:3]

with open(source, encoding="utf-8") as handle:
    data = json.load(handle)

data["graph_discovery"]["stage1"]["execution_authorized"] = True

with open(target, "w", encoding="utf-8") as handle:
    json.dump(data, handle, indent=2)
    handle.write("\n")
PY

expect_rejected \
  "stage1-premature-authorization" \
  env FEATURE9_CONFIG_FILE="$TMP/stage1-authorized.json" \
  ./scripts/validate-feature-9.sh

python3 - "$TMP/config.json" "$TMP/stage2-authorized.json" <<'PY'
import json
import sys

source, target = sys.argv[1:3]

with open(source, encoding="utf-8") as handle:
    data = json.load(handle)

data["graph_discovery"]["stage2"]["execution_authorized"] = True

with open(target, "w", encoding="utf-8") as handle:
    json.dump(data, handle, indent=2)
    handle.write("\n")
PY

expect_rejected \
  "stage2-premature-authorization" \
  env FEATURE9_CONFIG_FILE="$TMP/stage2-authorized.json" \
  ./scripts/validate-feature-9.sh

sed \
  's/application_permissions_default: deny_unless_justified/application_permissions_default: allow/' \
  "$TMP/policy.yaml" \
  > "$TMP/policy-allow.yaml"

expect_rejected \
  "application-permissions-allow-default" \
  env FEATURE9_POLICY_FILE="$TMP/policy-allow.yaml" \
  ./scripts/validate-feature-9.sh

sed \
  '0,/-Method GET/s//-Method POST/' \
  "$TMP/stage1.ps1" \
  > "$TMP/stage1-post.ps1"

expect_rejected \
  "stage1-post-method" \
  env FEATURE9_STAGE1_SCRIPT="$TMP/stage1-post.ps1" \
  ./scripts/validate-feature-9.sh

sed \
  's/"device_compliance": "feature8"/"device_compliance": "feature9"/' \
  "$TMP/auth.json" \
  > "$TMP/auth-regression.json"

expect_rejected \
  "device-compliance-regression" \
  env FEATURE9_AUTH_CONFIG_FILE="$TMP/auth-regression.json" \
  ./scripts/validate-feature-9.sh

echo
echo "FEATURE_9_ADVERSARIAL_TESTS=PASS"
