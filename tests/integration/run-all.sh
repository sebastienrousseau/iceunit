#!/usr/bin/env bash
set -euo pipefail

PASS=0
FAIL=0
ERRORS=()

run_test() {
    local name="$1"
    shift

    echo ""
    echo "━━━ $name ━━━"

    if "$@" 2>&1; then
        echo "PASS: $name"
        PASS=$((PASS + 1))
    else
        local rc=$?
        echo "FAIL: $name (exit $rc)"
        FAIL=$((FAIL + 1))
        ERRORS+=("$name")
    fi
}

# ── Read-only tests (safe to run without --dry-run) ──────────────────────────

run_test "02-wifi-firmware: verify" \
    bash scripts/02-wifi-firmware.sh verify

run_test "02-wifi-firmware: backup" \
    bash scripts/02-wifi-firmware.sh backup

run_test "02-wifi-firmware: --help" \
    bash scripts/02-wifi-firmware.sh --help

run_test "04-bootloader: --help" \
    bash scripts/04-bootloader.sh --help

run_test "05-mount-vault: --help" \
    bash scripts/05-mount-vault.sh --help

run_test "06-unmount-vault: --help" \
    bash scripts/06-unmount-vault.sh --help

# ── Dry-run tests (exercise code paths without system changes) ───────────────

run_test "05-mount-vault: --dry-run" \
    bash scripts/05-mount-vault.sh --dry-run

run_test "06-unmount-vault: --dry-run" \
    bash scripts/06-unmount-vault.sh --dry-run

# ── Results ──────────────────────────────────────────────────────────────────

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Results: ${PASS} passed, ${FAIL} failed"

if [ ${#ERRORS[@]} -gt 0 ]; then
    echo "Failed tests:"
    for e in "${ERRORS[@]}"; do
        echo "  - $e"
    done
    exit 1
fi

echo "All integration tests passed."
