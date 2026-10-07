#!/usr/bin/env bash

set -euo pipefail

ROOT="$(git rev-parse --show-toplevel)"
cd "$ROOT"

VALIDATOR="./scripts/validate-repository.sh"
OUTPUT="$(mktemp)"

TEST_PATHS=(
  ".validation-private-key.txt"
  ".validation-secret.txt"
  ".validation-credential.pem"
  "raw-evidence/validation-test.txt"
)

cleanup_path() {
  local path="$1"

  git reset -q HEAD -- "$path" >/dev/null 2>&1 || true
  rm -f -- "$path" >/dev/null 2>&1 || true
}

cleanup_all() {
  for path in "${TEST_PATHS[@]}"; do
    cleanup_path "$path"
  done

  rmdir raw-evidence >/dev/null 2>&1 || true
  rm -f "$OUTPUT" >/dev/null 2>&1 || true
}

trap cleanup_all EXIT INT TERM

run_failure_case() {
  local name="$1"
  local path="$2"
  local content="$3"
  local expected="$4"

  echo
  echo "=================================================="
  echo "TEST: $name"
  echo "=================================================="

  mkdir -p "$(dirname "$path")"
  printf '%s\n' "$content" > "$path"

  git add -f -- "$path"

  set +e
  "$VALIDATOR" >"$OUTPUT" 2>&1
  local result=$?
  set -e

  if [[ "$result" -eq 0 ]]; then
    echo "FAIL: validator unexpectedly accepted unsafe fixture."
    cat "$OUTPUT"
    exit 1
  fi

  if ! grep -Fq "$expected" "$OUTPUT"; then
    echo "FAIL: validator failed, but not for the expected reason."
    echo
    cat "$OUTPUT"
    exit 1
  fi

  echo "PASS: validator rejected the fixture for the expected reason."

  cleanup_path "$path"
}

PRIVATE_KEY_FIXTURE="$(
  printf '%s\n%s\n%s' \
    "-----BEGIN PRIVATE"" KEY-----" \
    "FAKE-VALIDATION-DATA-ONLY" \
    "-----END PRIVATE"" KEY-----"
)"

SECRET_FIXTURE="client""_secret = FAKE_VALIDATION_TEST_ONLY"

echo "=================================================="
echo "REPOSITORY VALIDATOR ADVERSARIAL TEST SUITE"
echo "=================================================="

run_failure_case \
  "Private key marker" \
  ".validation-private-key.txt" \
  "$PRIVATE_KEY_FIXTURE" \
  "private-key material detected."

run_failure_case \
  "Hard-coded client secret" \
  ".validation-secret.txt" \
  "$SECRET_FIXTURE" \
  "possible hard-coded secret assignment detected."

run_failure_case \
  "High-risk credential extension" \
  ".validation-credential.pem" \
  "FAKE VALIDATION FILE - NOT A REAL CREDENTIAL" \
  "high-risk credential files are tracked:"

run_failure_case \
  "Forbidden raw evidence path" \
  "raw-evidence/validation-test.txt" \
  "FAKE SANITIZED VALIDATION DATA" \
  "sensitive/local paths are tracked:"

echo
echo "=================================================="
echo "FINAL BASELINE VALIDATION"
echo "=================================================="

"$VALIDATOR"

echo
echo "=================================================="
echo "ALL REPOSITORY VALIDATION TESTS PASSED"
echo "=================================================="
