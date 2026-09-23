#!/usr/bin/env bash
set -euo pipefail

PACKAGE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PACKAGE_ROOT"

GITLEAKS="${1:-${GITLEAKS:-gitleaks}}"

run_dir_scan() {
    local source="$1"
    "$GITLEAKS" dir --no-banner --redact --config "$PACKAGE_ROOT/.gitleaks.toml" "$source" >/dev/null
}

run_git_scan() {
    "$GITLEAKS" git --no-banner --redact --verbose .
}

pass() { printf '  ✓ %s\n' "$1"; }

fail() {
    printf '  ✗ %s\n' "$1" >&2
    exit 1
}

copy_target_tree() {
    local destination="$1"
    mkdir -p \
        "$destination/Sources/UttrflowAccount" \
        "$destination/Tests/UttrflowAccountTests" \
        "$destination/Tests/UttrflowClipboardTests"
    cp .gitleaks.toml "$destination/.gitleaks.toml"
    cp Sources/UttrflowAccount/InMemoryAuthenticationService.swift \
        "$destination/Sources/UttrflowAccount/InMemoryAuthenticationService.swift"
    cp Tests/UttrflowAccountTests/AccountSupport.swift \
        "$destination/Tests/UttrflowAccountTests/AccountSupport.swift"
    cp Tests/UttrflowClipboardTests/SecretDetectionTests.swift \
        "$destination/Tests/UttrflowClipboardTests/SecretDetectionTests.swift"
}

cleanup_scratch() {
    [[ -n "${scratch:-}" && -d "$scratch" ]] || return 0
    find "$scratch" -depth -type f -delete
    find "$scratch" -depth -type d -empty -delete
}

assert_rejects_planted_secret() {
    local file="$1"
    local scratch="$2"
    printf '\nlet plantedCredential = "%s%s = %s%s"\n' \
        'api_' 'key' '9f2b7c4e' '1a8d3f6b' >> "$scratch/$file"
    if run_dir_scan "$scratch"; then
        fail "$file allowed a planted api-key-shaped credential"
    fi
    pass "$file rejects a planted api-key-shaped credential"
}

printf 'Gitleaks allowlist fixtures\n'

if ! command -v "$GITLEAKS" >/dev/null 2>&1 && [[ ! -x "$GITLEAKS" ]]; then
    fail "gitleaks executable not found: $GITLEAKS"
fi

scratch="$(mktemp -d)"
trap cleanup_scratch EXIT

copy_target_tree "$scratch/current"
run_dir_scan "$scratch/current"
pass "current targeted files scan clean without path exemptions for account files"

copy_target_tree "$scratch/in-memory-service"
assert_rejects_planted_secret \
    "Sources/UttrflowAccount/InMemoryAuthenticationService.swift" \
    "$scratch/in-memory-service"

copy_target_tree "$scratch/account-support"
assert_rejects_planted_secret \
    "Tests/UttrflowAccountTests/AccountSupport.swift" \
    "$scratch/account-support"

printf '\nFull repository history\n'
run_git_scan
