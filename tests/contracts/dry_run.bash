#!/usr/bin/env bash
# =============================================================================
# dry_run.bash — Contract tests for --dry-run and --help patterns
# =============================================================================
# shellcheck disable=SC2154  # $status and $output are set by bats `run`

# Assert script runs in dry-run mode without error and prints DRY-RUN
# Requires: RUNNABLE_SCRIPT set by prepare_runnable_script
assert_dry_run_succeeds() {
    run bash "$RUNNABLE_SCRIPT" --dry-run

    [ "$status" -eq 0 ]
    [[ "$output" == *"DRY-RUN"* ]]
}

# Assert script --help shows Usage and exits 0
# Requires: RUNNABLE_SCRIPT set by prepare_runnable_script
assert_help_shows_usage() {
    run bash "$RUNNABLE_SCRIPT" --help

    [ "$status" -eq 0 ]
    [[ "$output" == *"Usage"* ]]
}
