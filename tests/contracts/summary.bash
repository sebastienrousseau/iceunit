#!/usr/bin/env bash
# =============================================================================
# summary.bash — Contract tests for print_summary output
# =============================================================================
# shellcheck disable=SC2154  # $status and $output are set by bats `run`

# Assert print_summary shows expected items and "complete" message
# Usage: assert_summary_shows_items <applied_csv> <skipped_csv>
#   applied_csv: comma-separated list of applied items (e.g. "fonts,microcode")
#   skipped_csv: comma-separated list of skipped items (e.g. "desktop-environment")
assert_summary_shows_items() {
    local applied_csv="$1"
    local skipped_csv="${2:-}"

    # Set up APPLIED array
    IFS=',' read -ra APPLIED <<< "$applied_csv"
    export APPLIED

    # Set up SKIPPED array
    if [[ -n "$skipped_csv" ]]; then
        IFS=',' read -ra SKIPPED <<< "$skipped_csv"
    else
        SKIPPED=()
    fi
    export SKIPPED

    run print_summary

    [ "$status" -eq 0 ]
    # Verify each applied item appears in output
    for item in "${APPLIED[@]}"; do
        [[ "$output" == *"$item"* ]]
    done
    # Verify each skipped item appears in output
    for item in "${SKIPPED[@]}"; do
        [[ "$output" == *"$item"* ]]
    done
    [[ "$output" == *"complete"* ]] || [[ "$output" == *"Complete"* ]] || [[ "$output" == *"Reboot"* ]]
}
