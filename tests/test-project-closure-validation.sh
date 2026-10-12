#!/usr/bin/env bash
set -euo pipefail

ROOT="$(
  cd "$(dirname "${BASH_SOURCE[0]}")/.." &&
  pwd
)"

cd "$ROOT"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

cp configs/project-closure.json \
  "$TMP/config.json"

cp docs/evidence/project-final-closure-validation.json \
  "$TMP/evidence.json"

cp README.md \
  "$TMP/README.md"

expect_rejected() {
  local name="$1"
  shift

  set +e
  "$@" >"$TMP/$name.out" 2>&1
  local rc=$?
  set -e

  if [[ "$rc" -eq 0 ]]; then
    echo "FAIL: closure validator accepted adversarial fixture: $name"
    cat "$TMP/$name.out"
    exit 1
  fi

  echo "PASS: closure validator rejected adversarial fixture: $name"
}

echo "===== PROJECT CLOSURE BASELINE ====="

./scripts/validate-project-closure.sh

echo
echo "===== PROJECT CLOSURE ADVERSARIAL ====="

python3 - "$TMP/config.json" "$TMP/not-complete.json" <<'PY'
import json
import sys

source, target = sys.argv[1:3]

with open(source, encoding="utf-8") as handle:
    data = json.load(handle)

data["portfolio_status"] = "in_progress"

with open(target, "w", encoding="utf-8") as handle:
    json.dump(data, handle, indent=2)
    handle.write("\n")
PY

expect_rejected \
  "portfolio-not-complete" \
  env PROJECT_CLOSURE_CONFIG_FILE="$TMP/not-complete.json" \
  ./scripts/validate-project-closure.sh

python3 - "$TMP/config.json" "$TMP/production-claim.json" <<'PY'
import json
import sys

source, target = sys.argv[1:3]

with open(source, encoding="utf-8") as handle:
    data = json.load(handle)

data["scope"]["production_deployment_claimed"] = True

with open(target, "w", encoding="utf-8") as handle:
    json.dump(data, handle, indent=2)
    handle.write("\n")
PY

expect_rejected \
  "production-deployment-claim" \
  env PROJECT_CLOSURE_CONFIG_FILE="$TMP/production-claim.json" \
  ./scripts/validate-project-closure.sh

python3 - "$TMP/config.json" "$TMP/feature7-regression.json" <<'PY'
import json
import sys

source, target = sys.argv[1:3]

with open(source, encoding="utf-8") as handle:
    data = json.load(handle)

data["feature_status"]["feature7"] = "implemented"

with open(target, "w", encoding="utf-8") as handle:
    json.dump(data, handle, indent=2)
    handle.write("\n")
PY

expect_rejected \
  "feature7-license-deferral-hidden" \
  env PROJECT_CLOSURE_CONFIG_FILE="$TMP/feature7-regression.json" \
  ./scripts/validate-project-closure.sh

python3 - "$TMP/config.json" "$TMP/feature8-regression.json" <<'PY'
import json
import sys

source, target = sys.argv[1:3]

with open(source, encoding="utf-8") as handle:
    data = json.load(handle)

data["feature_status"]["feature8"] = "runtime_validated"

with open(target, "w", encoding="utf-8") as handle:
    json.dump(data, handle, indent=2)
    handle.write("\n")
PY

expect_rejected \
  "feature8-runtime-overclaim" \
  env PROJECT_CLOSURE_CONFIG_FILE="$TMP/feature8-regression.json" \
  ./scripts/validate-project-closure.sh

python3 - "$TMP/config.json" "$TMP/consent-pending.json" <<'PY'
import json
import sys

source, target = sys.argv[1:3]

with open(source, encoding="utf-8") as handle:
    data = json.load(handle)

data["feature9_application_read_all_cleanup"]["status"] = "pending"

with open(target, "w", encoding="utf-8") as handle:
    json.dump(data, handle, indent=2)
    handle.write("\n")
PY

expect_rejected \
  "consent-cleanup-pending" \
  env PROJECT_CLOSURE_CONFIG_FILE="$TMP/consent-pending.json" \
  ./scripts/validate-project-closure.sh

python3 - "$TMP/config.json" "$TMP/false-graph-verification.json" <<'PY'
import json
import sys

source, target = sys.argv[1:3]

with open(source, encoding="utf-8") as handle:
    data = json.load(handle)

data["feature9_application_read_all_cleanup"][
    "graph_revalidation_performed"
] = True

with open(target, "w", encoding="utf-8") as handle:
    json.dump(data, handle, indent=2)
    handle.write("\n")
PY

expect_rejected \
  "unsupported-graph-cleanup-verification" \
  env PROJECT_CLOSURE_CONFIG_FILE="$TMP/false-graph-verification.json" \
  ./scripts/validate-project-closure.sh

cat "$TMP/README.md" > "$TMP/stale-readme.md"

cat >> "$TMP/stale-readme.md" <<'STALE'
## Feature 3 — Identity Foundation

Status: in progress.
STALE

expect_rejected \
  "stale-readme-state" \
  env PROJECT_CLOSURE_README_FILE="$TMP/stale-readme.md" \
  ./scripts/validate-project-closure.sh

python3 - "$TMP/evidence.json" "$TMP/privacy-regression.json" <<'PY'
import json
import sys

source, target = sys.argv[1:3]

with open(source, encoding="utf-8") as handle:
    data = json.load(handle)

data["privacy"]["tenant_ids_committed"] = True

with open(target, "w", encoding="utf-8") as handle:
    json.dump(data, handle, indent=2)
    handle.write("\n")
PY

expect_rejected \
  "privacy-regression" \
  env PROJECT_CLOSURE_EVIDENCE_FILE="$TMP/privacy-regression.json" \
  ./scripts/validate-project-closure.sh

echo
echo "PROJECT_CLOSURE_ADVERSARIAL_TESTS=PASS"
