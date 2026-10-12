#!/usr/bin/env bash
set -euo pipefail

ROOT="$(
  cd "$(dirname "${BASH_SOURCE[0]}")/.." &&
  pwd
)"

cd "$ROOT"

architecture="${FEATURE9_ARCHITECTURE_FILE:-docs/architecture/feature-9-enterprise-application-permission-governance.md}"
adr="${FEATURE9_ADR_FILE:-docs/decisions/adr-009-enterprise-application-permission-governance.md}"
guardrails="${FEATURE9_GUARDRAILS_FILE:-docs/security/feature-9-enterprise-application-guardrails.md}"
plan="${FEATURE9_PLAN_FILE:-docs/testing/feature-9-validation-plan.md}"
config="${FEATURE9_CONFIG_FILE:-configs/enterprise-application-governance.json}"
policy="${FEATURE9_POLICY_FILE:-policies/apps/enterprise-application-permission-baseline.yaml}"
stage1="${FEATURE9_STAGE1_SCRIPT:-automation/powershell/Get-EnterpriseApplicationInventory.ps1}"
stage2="${FEATURE9_STAGE2_SCRIPT:-automation/powershell/Get-DelegatedPermissionGrantInventory.ps1}"
auth_config="${FEATURE9_AUTH_CONFIG_FILE:-configs/authentication-mfa.json}"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

require_file() {
  [[ -f "$1" ]] || fail "missing required Feature 9 artifact: $1"
}

require_literal() {
  local file="$1"
  local literal="$2"

  grep -Fq -- "$literal" "$file" ||
    fail "missing required literal in $file: $literal"
}

required=(
  "$architecture"
  "$adr"
  "$guardrails"
  "$plan"
  "$config"
  "$policy"
  "$stage1"
  "$stage2"
  "$auth_config"
)

echo "===== FEATURE 9A FOUNDATION VALIDATION ====="

for file in "${required[@]}"; do
  require_file "$file"
done

python3 - "$config" <<'PY'
import json
import sys

path = sys.argv[1]

with open(path, encoding="utf-8") as handle:
    data = json.load(handle)

def require(condition, message):
    if not condition:
        raise SystemExit(f"FAIL: {message}")

require(data["feature"] == "feature9", "unexpected feature")
require(
    data["phase"] == "feature9a-foundation",
    "unexpected Feature 9 lifecycle phase",
)
require(
    data["implementation_state"]
    == "design_ready_read_only_discovery_pending",
    "unexpected implementation state",
)

authorization = data["authorization"]

for key in (
    "tenant_writes",
    "application_registration_creation",
    "service_principal_mutation",
    "credential_creation",
    "credential_rotation",
    "permission_grant_creation",
    "permission_grant_removal",
    "admin_consent",
    "user_assignment_changes",
    "service_principal_deletion",
):
    require(
        authorization[key] is False,
        f"authorization must remain false: {key}",
    )

stage1 = data["graph_discovery"]["stage1"]
stage2 = data["graph_discovery"]["stage2"]

require(
    stage1["scope"] == "Application.Read.All",
    "Stage 1 scope changed",
)
require(
    stage1["http_methods"] == ["GET"],
    "Stage 1 must remain GET-only",
)
require(
    stage1["execution_authorized"] is False,
    "Stage 1 execution prematurely authorized",
)

require(
    stage2["scope"] == "Directory.Read.All",
    "Stage 2 scope changed",
)
require(
    stage2["http_methods"] == ["GET"],
    "Stage 2 must remain GET-only",
)
require(
    stage2["execution_authorized"] is False,
    "Stage 2 execution prematurely authorized",
)

governance = data["governance"]

for key in (
    "least_privilege_required",
    "delegated_and_application_permissions_separated",
    "permission_business_justification_required",
    "owner_accountability_required",
    "admin_consent_requires_separate_gate",
    "permission_expansion_requires_separate_review",
    "broad_tenant_assignment_prohibited_by_default",
    "first_party_service_principal_mutation_prohibited",
):
    require(
        governance[key] is True,
        f"governance requirement disabled: {key}",
    )

privacy = data["privacy"]

for key in (
    "repository_contains_object_ids",
    "repository_contains_tenant_ids",
    "repository_contains_real_upns",
    "repository_contains_tokens",
    "repository_contains_client_secrets",
    "repository_contains_private_keys",
):
    require(
        privacy[key] is False,
        f"privacy boundary violated: {key}",
    )

require(
    privacy["sanitized_aggregate_evidence_only"] is True,
    "sanitized evidence requirement disabled",
)

print("PASS: Feature 9 JSON governance contract valid.")
PY

require_literal "$policy" \
  "application_permissions_default: deny_unless_justified"

require_literal "$policy" \
  "delegated_permissions_default: deny_unless_justified"

require_literal "$policy" \
  "admin_consent_default: deny"

require_literal "$policy" \
  "all_users_assignment_authorized: false"

require_literal "$policy" \
  "client_secret_creation_authorized: false"

require_literal "$policy" \
  "certificate_credential_creation_authorized: false"

require_literal "$policy" \
  "permission_grant_creation_authorized: false"

require_literal "$policy" \
  "permission_grant_removal_authorized: false"

require_literal "$policy" \
  "admin_consent_authorized: false"

require_literal "$policy" \
  "stage1_scope: Application.Read.All"

require_literal "$policy" \
  "stage1_method: GET_ONLY"

require_literal "$policy" \
  "stage1_execution_authorized: false"

require_literal "$policy" \
  "stage2_scope: Directory.Read.All"

require_literal "$policy" \
  "stage2_method: GET_ONLY"

require_literal "$policy" \
  "stage2_execution_authorized: false"

require_literal "$policy" \
  "device_compliance_owner: feature8"

require_literal "$auth_config" \
  '"device_compliance": "feature8"'

for script in "$stage1" "$stage2"; do
  grep -Eq -- '-Method[[:space:]]+GET' "$script" ||
    fail "Graph collector does not contain an explicit GET: $script"

  if grep -Eiq -- \
    '-Method[[:space:]]+(POST|PATCH|PUT|DELETE)' \
    "$script"
  then
    fail "Graph collector contains a mutation HTTP method: $script"
  fi

  if grep -Eiq -- \
    '\b(New|Update|Remove|Set)-Mg[A-Za-z0-9]+' \
    "$script"
  then
    fail "Graph collector contains a mutation cmdlet: $script"
  fi

  grep -Fq \
    'tenant_writes = 0' \
    "$script" ||
    fail "collector lacks zero-write evidence: $script"

  grep -Fq \
    'identifiers_emitted = $false' \
    "$script" ||
    fail "collector lacks identifier privacy guardrail: $script"
done

require_literal "$stage1" \
  '$RequiredScope = "Application.Read.All"'

require_literal "$stage2" \
  '$RequiredScope = "Directory.Read.All"'

require_literal "$architecture" \
  "Phase 9A is repository and design work only."

require_literal "$architecture" \
  "Phase 9B is not authorized by Phase 9A"

require_literal "$architecture" \
  "Phase 9C requires a separate explicit execution decision"

require_literal "$guardrails" \
  '`TENANT_WRITES_AUTHORIZED=NO`'

require_literal "$guardrails" \
  '`ADMIN_CONSENT_AUTHORIZED=NO`'

require_literal "$adr" \
  "Feature 9A authorizes zero tenant writes."

require_literal "$plan" \
  "Phase 9A performs no live Graph request."

set +e

grep -REni \
  --exclude='authentication-mfa.json' \
  -- \
  '-----BEGIN ((OPENSSH|RSA|EC|DSA) )?PRIVATE[[:space:]]+KEY-----|Bearer[[:space:]]+[A-Za-z0-9._-]{20,}|[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}|[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}' \
  "$architecture" \
  "$adr" \
  "$guardrails" \
  "$plan" \
  "$config" \
  "$policy" \
  "$stage1" \
  "$stage2"

sensitive_rc=$?

set -e

case "$sensitive_rc" in
  0)
    fail "tenant-specific or credential-like material detected"
    ;;
  1)
    ;;
  *)
    fail "sensitive-material scan failed unexpectedly"
    ;;
esac

echo "FEATURE_9_VALIDATION=PASS"
echo "FEATURE_9_PHASE=FOUNDATION"
echo "FEATURE_9_IMPLEMENTATION_STATE=DESIGN_READY_READ_ONLY_DISCOVERY_PENDING"
echo "FEATURE_9_STAGE1_SCOPE=APPLICATION_READ_ALL"
echo "FEATURE_9_STAGE1_EXECUTION_AUTHORIZED=NO"
echo "FEATURE_9_STAGE2_SCOPE=DIRECTORY_READ_ALL"
echo "FEATURE_9_STAGE2_EXECUTION_AUTHORIZED=NO"
echo "FEATURE_9_GRAPH_METHOD=GET_ONLY"
echo "FEATURE_9_TENANT_WRITES_AUTHORIZED=NO"
echo "FEATURE_9_APPLICATION_CREATION_AUTHORIZED=NO"
echo "FEATURE_9_ADMIN_CONSENT_AUTHORIZED=NO"
echo "FEATURE_9_CREDENTIAL_CREATION_AUTHORIZED=NO"
echo "DEVICE_COMPLIANCE_OWNER=FEATURE8"
