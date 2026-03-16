#!/usr/bin/env bash
# =============================================================================
# service_enable.bash — Contract tests for service enable/skip patterns
# =============================================================================
# shellcheck disable=SC2154  # $status and $output are set by bats `run`

# Assert a function skips when a service is already enabled
# Usage: assert_service_skip_when_enabled <function_name> <service_name> <expected_output>
assert_service_skip_when_enabled() {
    local func="$1"
    local svc="$2"
    local expected="$3"
    mock_command_conditional systemctl "is-enabled ${svc}" 0 0

    run "$func"

    [ "$status" -eq 0 ]
    [[ "$output" == *"$expected"* ]]
}

# Assert a function enables a disabled service
# Usage: assert_service_enables_when_disabled <function_name> <service_name> <expected_output>
assert_service_enables_when_disabled() {
    local func="$1"
    local svc="$2"
    local expected="$3"
    mock_command_conditional systemctl "is-enabled ${svc}" 1 0

    run "$func"

    [ "$status" -eq 0 ]
    [[ "$output" == *"$expected"* ]]
}
