#!/usr/bin/env bash
set -euo pipefail

ROOT="$(
  cd "$(dirname "${BASH_SOURCE[0]}")/.." &&
  pwd
)"

cd "$ROOT"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

cp \
  docs/evidence/feature-9b-enterprise-application-inventory-validation.json \
  "$TMP/evidence.json"

cp \
  configs/enterprise-application-governance.json \
  "$TMP/config.json"

cp \
  policies/apps/enterprise-application-permission-baseline.yaml \
  "$TMP/policy.yaml"

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

echo "===== FEATURE 9B BASELINE ====="

./scripts/validate-feature-9b.sh

echo
echo "===== FEATURE 9B ADVERSARIAL ====="

python3 - "$TMP/evidence.json" "$TMP/no-consent.json" <<'PY'
import json
import sys

source, target = sys.argv[1:3]

with open(source, encoding="utf-8") as handle:
    data = json.load(handle)

data["authentication_consent_event"][
    "consent_prompt_accepted_by_operator"
] = False

with open(target, "w", encoding="utf-8") as handle:
    json.dump(data, handle, indent=2)
    handle.write("\n")
PY

expect_rejected \
  "accepted-consent-removed" \
  env FEATURE9B_EVIDENCE_FILE="$TMP/no-consent.json" \
  ./scripts/validate-feature-9b.sh

python3 - "$TMP/evidence.json" "$TMP/no-auth-change.json" <<'PY'
import json
import sys

source, target = sys.argv[1:3]

with open(source, encoding="utf-8") as handle:
    data = json.load(handle)

data["authentication_consent_event"][
    "tenant_authorization_state_changed"
] = False

with open(target, "w", encoding="utf-8") as handle:
    json.dump(data, handle, indent=2)
    handle.write("\n")
PY

expect_rejected \
  "authorization-change-hidden" \
  env FEATURE9B_EVIDENCE_FILE="$TMP/no-auth-change.json" \
  ./scripts/validate-feature-9b.sh

python3 - "$TMP/evidence.json" "$TMP/false-allprincipals.json" <<'PY'
import json
import sys

source, target = sys.argv[1:3]

with open(source, encoding="utf-8") as handle:
    data = json.load(handle)

data["authentication_consent_event"][
    "exact_oauth2_permission_grant_consent_type"
] = "AllPrincipals"

with open(target, "w", encoding="utf-8") as handle:
    json.dump(data, handle, indent=2)
    handle.write("\n")
PY

expect_rejected \
  "unsupported-allprincipals-claim" \
  env FEATURE9B_EVIDENCE_FILE="$TMP/false-allprincipals.json" \
  ./scripts/validate-feature-9b.sh

python3 - "$TMP/config.json" "$TMP/rerun.json" <<'PY'
import json
import sys

source, target = sys.argv[1:3]

with open(source, encoding="utf-8") as handle:
    data = json.load(handle)

data["live_validation"]["stage1"]["rerun_authorized"] = True

with open(target, "w", encoding="utf-8") as handle:
    json.dump(data, handle, indent=2)
    handle.write("\n")
PY

expect_rejected \
  "stage1-rerun-authorized" \
  env FEATURE9B_CONFIG_FILE="$TMP/rerun.json" \
  ./scripts/validate-feature-9b.sh

python3 - "$TMP/config.json" "$TMP/stage2.json" <<'PY'
import json
import sys

source, target = sys.argv[1:3]

with open(source, encoding="utf-8") as handle:
    data = json.load(handle)

data["live_validation"]["stage2"]["execution_authorized"] = True

with open(target, "w", encoding="utf-8") as handle:
    json.dump(data, handle, indent=2)
    handle.write("\n")
PY

expect_rejected \
  "stage2-premature-authorization" \
  env FEATURE9B_CONFIG_FILE="$TMP/stage2.json" \
  ./scripts/validate-feature-9b.sh

sed \
  's/stage2_status: deferred_privilege_minimization/stage2_status: executed/' \
  "$TMP/policy.yaml" \
  > "$TMP/policy-stage2-executed.yaml"

expect_rejected \
  "stage2-policy-regression" \
  env FEATURE9B_POLICY_FILE="$TMP/policy-stage2-executed.yaml" \
  ./scripts/validate-feature-9b.sh

echo
echo "FEATURE_9B_ADVERSARIAL_TESTS=PASS"
