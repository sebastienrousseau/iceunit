#!/usr/bin/env bash
# =============================================================================
# assertions.bash — DSL-style assertion wrappers for readable tests
# =============================================================================
# shellcheck disable=SC2154  # $status and $output are set by bats `run`

# Assert command exited with status 0
then_status_ok() {
    if [[ "$status" -ne 0 ]]; then
        echo "FAIL: Expected status 0, got ${status}" >&2
        echo "Output: ${output}" >&2
        return 1
    fi
}

# Assert command exited with non-zero status
then_status_fails() {
    if [[ "$status" -eq 0 ]]; then
        echo "FAIL: Expected non-zero status, got 0" >&2
        echo "Output: ${output}" >&2
        return 1
    fi
}

# Assert output contains a string
# Usage: then_output_contains <expected_substring>
then_output_contains() {
    local expected="$1"
    if [[ "$output" != *"$expected"* ]]; then
        echo "FAIL: Expected output to contain '${expected}'" >&2
        echo "Actual output: ${output}" >&2
        return 1
    fi
}

# Assert output does NOT contain a string
# Usage: then_output_not_contains <unexpected_substring>
then_output_not_contains() {
    local unexpected="$1"
    if [[ "$output" == *"$unexpected"* ]]; then
        echo "FAIL: Expected output NOT to contain '${unexpected}'" >&2
        echo "Actual output: ${output}" >&2
        return 1
    fi
}

# Run --dry-run and assert all keyword args are present in output
# Usage: assert_dry_run_mentions <keyword1> [keyword2] ...
assert_dry_run_mentions() {
    for keyword in "$@"; do
        if [[ "$output" != *"$keyword"* ]]; then
            echo "FAIL: Expected dry-run output to mention '${keyword}'" >&2
            echo "Actual output: ${output}" >&2
            return 1
        fi
    done
}
