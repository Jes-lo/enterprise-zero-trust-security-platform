#!/usr/bin/env bash
set -euo pipefail

ROOT="$(
  cd "$(dirname "${BASH_SOURCE[0]}")/.." &&
  pwd
)"

cd "$ROOT"

config="${FEATURE9CLOSE_CONFIG_FILE:-configs/enterprise-application-governance.json}"
policy="${FEATURE9CLOSE_POLICY_FILE:-policies/apps/enterprise-application-permission-baseline.yaml}"
evidence="${FEATURE9CLOSE_EVIDENCE_FILE:-docs/evidence/feature-9b-enterprise-application-inventory-validation.json}"
adr="${FEATURE9CLOSE_ADR_FILE:-docs/decisions/adr-010-synthetic-enterprise-application-write-boundary.md}"
architecture="${FEATURE9CLOSE_ARCHITECTURE_FILE:-docs/architecture/feature-9-enterprise-application-permission-governance.md}"
guardrails="${FEATURE9CLOSE_GUARDRAILS_FILE:-docs/security/feature-9-enterprise-application-guardrails.md}"
plan="${FEATURE9CLOSE_PLAN_FILE:-docs/testing/feature-9-validation-plan.md}"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

for file in \
  "$config" \
  "$policy" \
  "$evidence" \
  "$adr" \
  "$architecture" \
  "$guardrails" \
  "$plan"
do
  [[ -f "$file" ]] || fail "missing Feature 9 closure artifact: $file"
done

echo "===== FEATURE 9 FOUNDATION / LIVE REGRESSION ====="

bash scripts/validate-feature-9.sh >/dev/null
bash scripts/validate-feature-9b.sh >/dev/null

echo "PASS: Feature 9A and Feature 9B regression."

echo
echo "===== FEATURE 9 FINAL CLOSURE CONTRACT ====="

python3 - \
  "$config" \
  "$evidence" <<'PY'
import json
import sys

config_path, evidence_path = sys.argv[1:3]

with open(config_path, encoding="utf-8") as handle:
    config = json.load(handle)

with open(evidence_path, encoding="utf-8") as handle:
    evidence = json.load(handle)


def require(condition, message):
    if not condition:
        raise SystemExit(f"FAIL: {message}")


closure = config["feature9_closure"]

require(
    closure["status"] == "validated_privilege_minimization",
    "unexpected Feature 9 closure status",
)
require(
    closure["enterprise_application_inventory"] == "validated",
    "enterprise application inventory not validated",
)
require(
    closure["delegated_permission_grant_inventory"]
    == "deferred_privilege_minimization",
    "Feature 9C deferral changed",
)
require(
    closure["closure_classification"]
    == "validated-no-additional-tenant-write-required",
    "unexpected closure classification",
)

synthetic = closure["synthetic_application"]

require(
    synthetic["status"] == "deferred_privilege_minimization",
    "synthetic application state changed",
)

for key in (
    "creation_authorized",
    "service_principal_creation_authorized",
    "application_readwrite_all_authorized",
    "directory_readwrite_all_authorized",
    "new_admin_role_authorized",
    "credential_creation_authorized",
    "additional_consent_authorized",
):
    require(
        synthetic[key] is False,
        f"forbidden synthetic write boundary enabled: {key}",
    )

summary = evidence["summary"]

require(
    summary["tenant_owned_service_principals"] == 0,
    "closure assumes zero tenant-owned service principals",
)
require(
    summary[
        "tenant_owned_application_permission_assignments"
    ] == 0,
    "closure assumes zero tenant-owned application-permission assignments",
)

require(
    closure["tenant_owned_service_principals_observed"]
    == summary["tenant_owned_service_principals"],
    "closure/evidence service-principal count mismatch",
)
require(
    closure[
        "tenant_owned_application_permission_assignments_observed"
    ]
    == summary[
        "tenant_owned_application_permission_assignments"
    ],
    "closure/evidence application-permission count mismatch",
)

print("PASS: Feature 9 final closure contract valid.")
PY

echo
echo "===== FEATURE 9 FINAL POLICY ====="

for literal in \
  "status: validated_privilege_minimization" \
  "synthetic_application_status: deferred_privilege_minimization" \
  "synthetic_application_creation_authorized: false" \
  "service_principal_creation_authorized: false" \
  "application_readwrite_all_authorized: false" \
  "directory_readwrite_all_authorized: false" \
  "new_admin_role_authorized: false" \
  "credential_creation_authorized: false" \
  "additional_consent_authorized: false" \
  "closure_classification: validated-no-additional-tenant-write-required"
do
  grep -Fq -- "$literal" "$policy" ||
    fail "missing closure policy marker: $literal"
done

echo
echo "===== FEATURE 9 FINAL DOCUMENTATION ====="

grep -Fq \
  '`FEATURE9_CLOSURE=VALIDATED_PRIVILEGE_MINIMIZATION`' \
  "$architecture" ||
  fail "architecture closure marker missing"

grep -Fq \
  '`FEATURE9_ADDITIONAL_TENANT_WRITE_REQUIRED=NO`' \
  "$architecture" ||
  fail "tenant-write closure marker missing"

grep -Fq \
  '`FEATURE9_APPLICATION_READWRITE_ALL_AUTHORIZED=NO`' \
  "$adr" ||
  fail "ADR Application.ReadWrite.All boundary missing"

grep -Fq \
  "Do not request \`Application.ReadWrite.All\`" \
  "$guardrails" ||
  fail "write-permission guardrail missing"

grep -Fq \
  "## Feature 9D closure criteria" \
  "$plan" ||
  fail "closure testing criteria missing"

echo
echo "===== FEATURE 9 FINAL PRIVACY ====="

set +e

grep -REni \
  -- \
  'Bearer[[:space:]]+[A-Za-z0-9._-]{20,}|[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}|[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}|-----BEGIN ((OPENSSH|RSA|EC|DSA) )?PRIVATE[[:space:]]+KEY-----' \
  "$config" \
  "$policy" \
  "$evidence" \
  "$adr" \
  "$architecture" \
  "$guardrails" \
  "$plan"

scan_rc=$?

set -e

case "$scan_rc" in
  0)
    fail "sensitive or tenant-specific material detected"
    ;;
  1)
    ;;
  *)
    fail "privacy scan failed unexpectedly"
    ;;
esac

echo "FEATURE_9_CLOSURE_VALIDATION=PASS"
echo "FEATURE_9_CLOSURE=VALIDATED_PRIVILEGE_MINIMIZATION"
echo "FEATURE_9_SYNTHETIC_APPLICATION=DEFERRED_PRIVILEGE_MINIMIZATION"
echo "FEATURE_9_APPLICATION_READWRITE_ALL_AUTHORIZED=NO"
echo "FEATURE_9_DIRECTORY_READWRITE_ALL_AUTHORIZED=NO"
echo "FEATURE_9_NEW_ADMIN_ROLE_AUTHORIZED=NO"
echo "FEATURE_9_NEW_CREDENTIAL_AUTHORIZED=NO"
echo "FEATURE_9_ADDITIONAL_CONSENT_AUTHORIZED=NO"
echo "FEATURE_9_ADDITIONAL_TENANT_WRITE_REQUIRED=NO"
