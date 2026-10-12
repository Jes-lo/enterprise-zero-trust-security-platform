#!/usr/bin/env bash
set -euo pipefail

ROOT="$(
  cd "$(dirname "${BASH_SOURCE[0]}")/.." &&
  pwd
)"

cd "$ROOT"

config="${PROJECT_CLOSURE_CONFIG_FILE:-configs/project-closure.json}"
evidence="${PROJECT_CLOSURE_EVIDENCE_FILE:-docs/evidence/project-final-closure-validation.json}"
readme="${PROJECT_CLOSURE_README_FILE:-README.md}"
architecture="${PROJECT_CLOSURE_ARCHITECTURE_FILE:-docs/architecture/project-final-closure.md}"
security="${PROJECT_CLOSURE_SECURITY_FILE:-docs/security/project-final-cleanup.md}"
plan="${PROJECT_CLOSURE_TEST_PLAN_FILE:-docs/testing/project-final-validation-plan.md}"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

for file in \
  "$config" \
  "$evidence" \
  "$readme" \
  "$architecture" \
  "$security" \
  "$plan"
do
  [[ -f "$file" ]] || fail "missing project closure artifact: $file"
done

echo "===== PROJECT FINAL CLOSURE CONTRACT ====="

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


require(
    config["project"] == "enterprise-zero-trust-security-platform",
    "unexpected project",
)
require(
    config["portfolio_status"] == "complete",
    "portfolio is not marked complete",
)
require(
    config["closure_classification"]
    == "validated-portfolio-complete",
    "unexpected closure classification",
)

scope = config["scope"]

require(
    scope["features_1_through_9"]
    == "completed_or_explicitly_deferred",
    "feature accounting changed",
)
require(
    scope["production_deployment_claimed"] is False,
    "production deployment falsely claimed",
)
require(
    scope["production_certification_claimed"] is False,
    "production certification falsely claimed",
)
require(
    scope["production_data_used"] is False,
    "production data use recorded",
)
require(
    scope["production_credentials_used"] is False,
    "production credential use recorded",
)

features = config["feature_status"]

expected_features = {
    "feature1": "completed",
    "feature2": "completed",
    "feature3": "completed",
    "feature4": "completed",
    "feature5": "completed_with_documented_operational_boundaries",
    "feature6": "validated_report_only_enforcement_deferred",
    "feature7": "validated_license_deferred",
    "feature8": "tenant_configured_runtime_environment_deferred",
    "feature9": "validated_privilege_minimization",
}

require(
    features == expected_features,
    "final feature-status contract changed",
)

deferred = config["intentional_deferred_boundaries"]

require(
    deferred["conditional_access_enforcement"]["status"]
    == "deferred",
    "Feature 6 enforcement deferral changed",
)
require(
    deferred[
        "pim_and_identity_protection_live_implementation"
    ]["status"]
    == "license_deferred",
    "Feature 7 license deferral changed",
)
require(
    deferred["endpoint_runtime_and_device_telemetry"]["status"]
    == "environment_deferred",
    "Feature 8 environment deferral changed",
)
require(
    deferred["delegated_permission_grant_inventory"]["status"]
    == "deferred_privilege_minimization",
    "Feature 9 delegated-grant boundary changed",
)
require(
    deferred["synthetic_enterprise_application"]["status"]
    == "deferred_privilege_minimization",
    "Feature 9 synthetic-app boundary changed",
)

cleanup = config["feature9_application_read_all_cleanup"]

require(
    cleanup["permission"] == "Application.Read.All",
    "unexpected cleanup permission",
)
require(
    cleanup["permission_type"] == "delegated",
    "unexpected permission type",
)
require(
    cleanup["consent_type"] == "admin_consent",
    "unexpected consent classification",
)
require(
    cleanup["cleanup_method"]
    == "selective_revoke_via_entra_admin_center",
    "unexpected cleanup method",
)
require(
    cleanup["status"] == "operator_confirmed_revoked",
    "Application.Read.All cleanup is not closed",
)
require(
    cleanup["repository_reauthentication_performed"] is False,
    "repository reauthentication unexpectedly recorded",
)
require(
    cleanup["graph_revalidation_performed"] is False,
    "unsupported Graph cleanup verification claim",
)
require(
    cleanup[
        "additional_graph_permission_requested_for_cleanup"
    ] is False,
    "additional Graph privilege was recorded for cleanup",
)

safety = config["closure_safety"]

for key in (
    "additional_tenant_write_required",
    "additional_license_required",
    "additional_consent_required",
    "synthetic_application_required",
    "branch_deletion_required",
):
    require(
        safety[key] is False,
        f"unexpected closure requirement enabled: {key}",
    )

for key, value in config["privacy"].items():
    require(
        value is False,
        f"privacy boundary violated: {key}",
    )

require(
    evidence["evidence_type"]
    == "project-final-closure-sanitized",
    "unexpected final evidence type",
)
require(
    evidence["portfolio_status"] == "complete",
    "evidence does not mark project complete",
)
require(
    evidence["features_1_through_9_accounted_for"] is True,
    "feature accounting evidence missing",
)
require(
    evidence[
        "feature9_merged_and_validated_before_closure"
    ] is True,
    "Feature 9 merge evidence missing",
)

consent = evidence["application_read_all_cleanup"]

require(
    consent["historical_consent_event_preserved"] is True,
    "historical Feature 9 consent evidence not preserved",
)
require(
    consent["selective_portal_revocation_performed"] is True,
    "selective portal revocation not recorded",
)
require(
    consent["operator_confirmed_revoked"] is True,
    "operator confirmation missing",
)
require(
    consent["graph_revalidation_performed"] is False,
    "unsupported Graph verification claim",
)
require(
    consent["new_graph_consent_requested_for_cleanup"] is False,
    "new Graph consent recorded during cleanup",
)
require(
    consent[
        "additional_tenant_write_by_repository_closure"
    ] is False,
    "repository closure tenant write recorded",
)

for key, value in evidence["privacy"].items():
    require(
        value is False,
        f"final evidence privacy boundary violated: {key}",
    )

print("PASS: project closure JSON contracts valid.")
PY

echo
echo "===== README FINAL STATUS ====="

grep -Fq \
  '**Status: Portfolio implementation complete.**' \
  "$readme" ||
  fail "README does not mark portfolio implementation complete"

if grep -Fq \
     'Status: in progress.' \
     "$readme"
then
  fail "stale in-progress README state remains"
fi

if grep -Fq \
     'the remaining nine planned live identities' \
     "$readme"
then
  fail "stale Feature 3 provisioning statement remains"
fi

grep -Fq \
  'VALIDATED-LICENSE-DEFERRED' \
  "$readme" ||
  fail "README omits Feature 7 license deferral"

grep -Fq \
  'ENVIRONMENT_DEFERRED' \
  "$readme" ||
  fail "README omits Feature 8 environment deferral"

grep -Fq \
  'operator-confirmed' \
  "$readme" ||
  fail "README omits consent cleanup classification"

echo
echo "===== CLOSURE DOCUMENT MARKERS ====="

grep -Fq \
  '`PROJECT_CLOSURE=VALIDATED_PORTFOLIO_COMPLETE`' \
  "$architecture" ||
  fail "architecture closure marker missing"

grep -Fq \
  '`APPLICATION_READ_ALL_CLEANUP=OPERATOR_CONFIRMED_REVOKED`' \
  "$architecture" ||
  fail "architecture consent cleanup marker missing"

grep -Fq \
  '`APPLICATION_READ_ALL_ADMIN_CONSENT=OPERATOR_CONFIRMED_REVOKED`' \
  "$security" ||
  fail "security cleanup marker missing"

grep -Fq \
  "The final closure validator and its adversarial tests are offline repository" \
  "$plan" ||
  fail "offline validation boundary missing"

echo
echo "===== NETWORK / GRAPH SAFETY ====="

graph_connect='Connect'"-MgGraph"
graph_invoke='Invoke'"-MgGraphRequest"
mutation_method='-[Mm]ethod[[:space:]]+(POST|PATCH|PUT|DELETE)'

if grep -Eiq \
  -- \
  "${graph_connect}|${graph_invoke}|${mutation_method}" \
  "${BASH_SOURCE[0]}"
then
  fail "project closure validator contains Graph/network mutation code"
fi

echo
echo "===== FINAL CLOSURE PRIVACY ====="

set +e

grep -REni \
  -- \
  'Bearer[[:space:]]+[A-Za-z0-9._-]{20,}|[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}|[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}|-----BEGIN ((OPENSSH|RSA|EC|DSA) )?PRIVATE[[:space:]]+KEY-----' \
  "$config" \
  "$evidence" \
  "$readme" \
  "$architecture" \
  "$security" \
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

echo "PROJECT_CLOSURE_VALIDATION=PASS"
echo "PROJECT_PORTFOLIO_STATUS=COMPLETE"
echo "FEATURES_1_THROUGH_9=ACCOUNTED_FOR"
echo "FEATURE6_ENFORCEMENT=DEFERRED"
echo "FEATURE7=P2_LICENSE_DEFERRED"
echo "FEATURE8_ENDPOINT_RUNTIME=ENVIRONMENT_DEFERRED"
echo "FEATURE9=VALIDATED_PRIVILEGE_MINIMIZATION"
echo "APPLICATION_READ_ALL_CLEANUP=OPERATOR_CONFIRMED_REVOKED"
echo "APPLICATION_READ_ALL_GRAPH_REVALIDATION=NOT_PERFORMED"
echo "ADDITIONAL_GRAPH_PERMISSION_FOR_CLEANUP=NO"
echo "ADDITIONAL_TENANT_WRITE_REQUIRED=NO"
echo "PRODUCTION_DEPLOYMENT_CLAIMED=NO"
echo "BRANCH_DELETION_REQUIRED=NO"
