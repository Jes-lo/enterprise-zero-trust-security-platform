#!/usr/bin/env bash

set -euo pipefail

echo "=================================================="
echo "ENTERPRISE ZERO TRUST PLATFORM"
echo "REPOSITORY SECURITY VALIDATION"
echo "=================================================="

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "FAIL: validation must run inside a Git repository."
  exit 1
fi

ROOT="$(git rev-parse --show-toplevel)"
cd "$ROOT"

scan_no_matches() {
  local fail_message="$1"
  local pass_message="$2"
  shift 2

  local working_output=""
  local index_output=""
  local working_exit=0
  local index_exit=0

  set +e

  working_output="$(git grep -nEI "$@" 2>&1)"
  working_exit=$?

  index_output="$(git grep --cached -nEI "$@" 2>&1)"
  index_exit=$?

  set -e

  if [[ "$working_exit" -gt 1 ]]; then
    echo "FAIL: working-tree scan failed with exit code $working_exit."
    printf '%s\n' "$working_output"
    exit 1
  fi

  if [[ "$index_exit" -gt 1 ]]; then
    echo "FAIL: index scan failed with exit code $index_exit."
    printf '%s\n' "$index_output"
    exit 1
  fi

  if [[ "$working_exit" -eq 0 || "$index_exit" -eq 0 ]]; then
    echo "FAIL: $fail_message"

    if [[ "$working_exit" -eq 0 ]]; then
      echo
      echo "Working-tree matches:"
      printf '%s\n' "$working_output"
    fi

    if [[ "$index_exit" -eq 0 ]]; then
      echo
      echo "Index/staged matches:"
      printf '%s\n' "$index_output"
    fi

    exit 1
  fi

  echo "PASS: $pass_message"
}

echo
echo "=================================================="
echo "1. REQUIRED GOVERNANCE FILES"
echo "=================================================="

REQUIRED_FILES=(
  "README.md"
  "COPYRIGHT.md"
  "LICENSE"
  "NOTICE.md"
  "SECURITY.md"
  "THIRD_PARTY_NOTICES.md"
  "TRADEMARKS.md"
  ".gitignore"
  ".gitattributes"
)

for file in "${REQUIRED_FILES[@]}"; do
  if [[ ! -f "$file" ]]; then
    echo "FAIL: required file missing: $file"
    exit 1
  fi

  echo "PASS: $file"
done

echo
echo "=================================================="
echo "2. PATCH INTEGRITY"
echo "=================================================="

git diff-tree \
  --check \
  --root \
  --no-commit-id \
  -r HEAD

echo "PASS: committed HEAD patch has no whitespace errors."

git diff --check
echo "PASS: working-tree patch has no whitespace errors."

git diff --cached --check
echo "PASS: staged patch has no whitespace errors."

echo
echo "=================================================="
echo "3. PRIVATE KEY MATERIAL"
echo "=================================================="

scan_no_matches \
  "private-key material detected." \
  "no private-key material detected." \
  -e '-----BEGIN ((OPENSSH|RSA|EC|DSA) )?PRIVATE[[:space:]]+KEY-----'

echo
echo "=================================================="
echo "4. COMMON SECRET ASSIGNMENTS"
echo "=================================================="

scan_no_matches \
  "possible hard-coded secret assignment detected." \
  "no common hard-coded secret assignments detected." \
  -e 'client[_-]?secret[[:space:]]*[:=][[:space:]]*[^[:space:]]+' \
  -e 'access[_-]?token[[:space:]]*[:=][[:space:]]*[^[:space:]]+' \
  -e 'refresh[_-]?token[[:space:]]*[:=][[:space:]]*[^[:space:]]+' \
  -e 'password[[:space:]]*[:=][[:space:]]*[^[:space:]]+' \
  -e 'api[_-]?key[[:space:]]*[:=][[:space:]]*[^[:space:]]+'

echo
echo "=================================================="
echo "5. HIGH-RISK TRACKED FILE TYPES"
echo "=================================================="

HIGH_RISK_FILES="$(
  git ls-files |
    grep -Ei '\.(pfx|p12|key|pem|jks|kdbx)$' || true
)"

if [[ -n "$HIGH_RISK_FILES" ]]; then
  echo "FAIL: high-risk credential files are tracked:"
  printf '%s\n' "$HIGH_RISK_FILES"
  exit 1
fi

echo "PASS: no high-risk credential file types tracked."

echo
echo "=================================================="
echo "6. FORBIDDEN TRACKED PATHS"
echo "=================================================="

FORBIDDEN_PATHS="$(
  git ls-files |
    grep -E '(^|/)(local-evidence|raw-evidence|raw-exports|secrets|credentials?)/' ||
    true
)"

if [[ -n "$FORBIDDEN_PATHS" ]]; then
  echo "FAIL: sensitive/local paths are tracked:"
  printf '%s\n' "$FORBIDDEN_PATHS"
  exit 1
fi

echo "PASS: no forbidden local/sensitive paths tracked."

echo
echo "=================================================="
echo "7. REQUIRED GITIGNORE PROTECTIONS"
echo "=================================================="

REQUIRED_IGNORE_PATTERNS=(
  ".env"
  "*.pfx"
  "*.p12"
  "*.key"
  "*.pem"
  "secrets/"
  "local-evidence/"
  "raw-evidence/"
  "raw-exports/"
)

for pattern in "${REQUIRED_IGNORE_PATTERNS[@]}"; do
  if ! grep -Fxq "$pattern" .gitignore; then
    echo "FAIL: .gitignore protection missing: $pattern"
    exit 1
  fi

  echo "PASS: $pattern"
done

echo
echo "=================================================="
echo "8. PROJECT INDEPENDENCE NOTICE"
echo "=================================================="

if ! grep -Fq \
  "It is not an official Microsoft product" \
  README.md; then
  echo "FAIL: Microsoft independence notice missing from README."
  exit 1
fi

if ! grep -Fq \
  "No ownership of third-party trademarks is claimed." \
  TRADEMARKS.md; then
  echo "FAIL: trademark ownership disclaimer missing."
  exit 1
fi

echo "PASS: independence and trademark notices present."

echo
echo "=================================================="
echo "9. WORKING TREE"
echo "=================================================="

STATUS="$(git status --porcelain)"

if [[ -n "$STATUS" ]]; then
  echo "INFO: working tree contains changes:"
  printf '%s\n' "$STATUS"
else
  echo "PASS: working tree clean."
fi

echo
echo "=================================================="
echo "REPOSITORY SECURITY VALIDATION PASSED"
echo "=================================================="
