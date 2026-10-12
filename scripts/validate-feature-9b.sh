#!/usr/bin/env bash
set -euo pipefail

ROOT="$(
  cd "$(dirname "${BASH_SOURCE[0]}")/.." &&
  pwd
)"

cd "$ROOT"

config="${FEATURE9B_CONFIG_FILE:-configs/enterprise-application-governance.json}"
policy="${FEATURE9B_POLICY_FILE:-policies/apps/enterprise-application-permission-baseline.yaml}"
evidence="${FEATURE9B_EVIDENCE_FILE:-docs/evidence/feature-9b-enterprise-application-inventory-validation.json}"
architecture="${FEATURE9B_ARCHITECTURE_FILE:-docs/architecture/feature-9-enterprise-application-permission-governance.md}"
adr="${FEATURE9B_ADR_FILE:-docs/decisions/adr-009-enterprise-application-permission-governance.md}"
guardrails="${FEATURE9B_GUARDRAILS_FILE:-docs/security/feature-9-enterprise-application-guardrails.md}"
plan="${FEATURE9B_PLAN_FILE:-docs/testing/feature-9-validation-plan.md}"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

for file in \
  "$config" \
  "$policy" \
  "$evidence" \
  "$architecture" \
  "$adr" \
  "$guardrails" \
  "$plan"
do
  [[ -f "$file" ]] || fail "missing Feature 9B artifact: $file"
done

echo "===== FEATURE 9A FOUNDATION REGRESSION ====="

bash scripts/validate-feature-9.sh >/dev/null

echo "PASS: Feature 9A foundation remains valid."

echo
echo "===== FEATURE 9B SANITIZED EVIDENCE ====="

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
    evidence["evidence_type"]
    == "feature9b-enterprise-application-inventory-sanitized",
    "unexpected evidence type",
)
require(evidence["feature"] == "feature9", "unexpected feature")
require(
    evidence["phase"] == "feature9b-read-only-inventory",
    "unexpected Feature 9B phase",
)
require(
    evidence["requested_delegated_permission"]
    == "Application.Read.All",
    "unexpected Stage 1 delegated permission",
)
require(
    evidence["graph_method"] == "GET_ONLY",
    "Stage 1 resource calls must remain GET-only",
)
require(
    evidence["authenticated_identity_validated"] is True,
    "identity validation not recorded",
)

summary = evidence["summary"]

count_keys = (
    "total_service_principals",
    "tenant_owned_service_principals",
    "tenant_owned_disabled_service_principals",
    "tenant_owned_ownerless_service_principals",
    "tenant_owned_application_permission_assignments",
    "tenant_owned_apps_with_application_permissions",
)

for key in count_keys:
    value = summary[key]

    require(
        isinstance(value, int) and not isinstance(value, bool),
        f"invalid count: {key}",
    )
    require(value >= 0, f"negative count: {key}")

require(
    summary["tenant_owned_service_principals"]
    <= summary["total_service_principals"],
    "tenant-owned count exceeds total count",
)

collector = evidence["collector_execution"]

require(
    collector["graph_mutation_http_methods"] == 0,
    "collector mutation call recorded",
)
require(
    collector["tenant_resource_writes"] == 0,
    "collector tenant-resource write recorded",
)
require(
    collector["identifiers_emitted"] is False,
    "collector identifier emission recorded",
)

consent = evidence["authentication_consent_event"]

require(
    consent["consent_prompt_presented"] is True,
    "consent prompt event missing",
)
require(
    consent["consent_prompt_accepted_by_operator"] is True,
    "accepted consent event missing",
)
require(
    consent["requested_permission_requires_admin_consent"] is True,
    "admin-consent requirement not recorded",
)
require(
    consent["tenant_authorization_state_changed"] is True,
    "tenant authorization state change not recorded",
)
require(
    consent["exact_oauth2_permission_grant_consent_type"]
    == "not_independently_verified",
    "unsupported OAuth2 grant-type claim",
)
require(
    consent["tenant_wide_consent"]
    == "not_independently_verified",
    "unsupported tenant-wide consent claim",
)

post = evidence["post_execution_authorization"]

require(
    post["stage1_rerun_authorized"] is False,
    "Stage 1 rerun unexpectedly authorized",
)
require(
    post["stage2_execution_authorized"] is False,
    "Stage 2 unexpectedly authorized",
)

stage2 = evidence["stage2_decision"]

require(
    stage2["status"] == "deferred_privilege_minimization",
    "unexpected Stage 2 state",
)
require(
    stage2["requested_scope_if_executed"] == "Directory.Read.All",
    "unexpected Stage 2 scope",
)

for value in evidence["privacy"].values():
    require(value is False, "privacy boundary violation recorded")

live = config["live_validation"]

require(
    live["stage1"]["status"] == "validated",
    "Stage 1 live state not validated",
)
require(
    live["stage1"]["scope"] == "Application.Read.All",
    "Stage 1 live scope changed",
)
require(
    live["stage1"]["graph_method"] == "GET_ONLY",
    "Stage 1 live method changed",
)
require(
    live["stage1"]["consent_prompt_accepted_by_operator"] is True,
    "config omitted accepted consent event",
)
require(
    live["stage1"]["tenant_authorization_state_changed"] is True,
    "config omitted authorization state change",
)
require(
    live["stage1"]["rerun_authorized"] is False,
    "Stage 1 rerun unexpectedly authorized",
)

require(
    live["stage2"]["status"]
    == "deferred_privilege_minimization",
    "Stage 2 is not least-privilege deferred",
)
require(
    live["stage2"]["scope"] == "Directory.Read.All",
    "Stage 2 scope changed",
)
require(
    live["stage2"]["execution_authorized"] is False,
    "Stage 2 execution unexpectedly authorized",
)
require(
    live["stage2"]["execution_completed"] is False,
    "Stage 2 unexpectedly marked complete",
)
require(
    live["stage2"]["new_consent_authorized"] is False,
    "new Stage 2 consent unexpectedly authorized",
)

print("PASS: Feature 9B sanitized evidence valid.")
print("PASS: consent-event classification valid.")
print("PASS: Feature 9C privilege-minimization deferral valid.")
PY

echo
echo "===== FEATURE 9B POLICY MARKERS ====="

grep -Fq \
  "stage1_consent_prompt_accepted_by_operator: true" \
  "$policy" ||
  fail "accepted consent marker missing"

grep -Fq \
  "stage1_tenant_authorization_state_changed: true" \
  "$policy" ||
  fail "authorization-state-change marker missing"

grep -Fq \
  "stage1_exact_oauth2_permission_grant_consent_type: not_independently_verified" \
  "$policy" ||
  fail "unverified consent-type marker missing"

grep -Fq \
  "stage1_rerun_authorized: false" \
  "$policy" ||
  fail "Stage 1 rerun guardrail missing"

grep -Fq \
  "stage2_status: deferred_privilege_minimization" \
  "$policy" ||
  fail "Stage 2 deferral marker missing"

grep -Fq \
  "stage2_execution_authorized: false" \
  "$policy" ||
  fail "Stage 2 authorization guardrail missing"

echo
echo "===== FEATURE 9B PRIVACY ====="

set +e

grep -REni \
  -- \
  'Bearer[[:space:]]+[A-Za-z0-9._-]{20,}|[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}|[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}|-----BEGIN ((OPENSSH|RSA|EC|DSA) )?PRIVATE[[:space:]]+KEY-----' \
  "$evidence" \
  "$architecture" \
  "$adr" \
  "$guardrails" \
  "$plan" \
  "$policy"

scan_rc=$?

set -e

case "$scan_rc" in
  0)
    fail "sensitive or identifying material detected"
    ;;
  1)
    ;;
  *)
    fail "privacy scan failed unexpectedly"
    ;;
esac

echo "FEATURE_9B_VALIDATION=PASS"
echo "FEATURE_9B_STAGE1=VALIDATED"
echo "FEATURE_9B_STAGE1_SCOPE=APPLICATION_READ_ALL"
echo "FEATURE_9B_STAGE1_GRAPH_METHOD=GET_ONLY"
echo "FEATURE_9B_COLLECTOR_GRAPH_MUTATION_METHODS=0"
echo "FEATURE_9B_COLLECTOR_TENANT_RESOURCE_WRITES=0"
echo "FEATURE_9B_CONSENT_EVENT=ACCEPTED"
echo "FEATURE_9B_TENANT_AUTHORIZATION_STATE_CHANGED=YES"
echo "FEATURE_9B_EXACT_CONSENT_TYPE=NOT_INDEPENDENTLY_VERIFIED"
echo "FEATURE_9B_STAGE1_RERUN_AUTHORIZED=NO"
echo "FEATURE_9C=DEFERRED_PRIVILEGE_MINIMIZATION"
echo "FEATURE_9C_SCOPE_IF_EXECUTED=DIRECTORY_READ_ALL"
echo "FEATURE_9C_EXECUTION_AUTHORIZED=NO"
