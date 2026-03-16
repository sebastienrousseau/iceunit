#!/usr/bin/env bash
# =============================================================================
# package_install.bash — Contract tests for package install/skip patterns
# =============================================================================
# shellcheck disable=SC2154  # $status and $output are set by bats `run`

# Assert a function skips when all packages are already installed
# Usage: assert_package_skip <function_name> <expected_output_substring>
assert_package_skip() {
    local func="$1"
    local expected="${2:-already installed}"
    mock_command pacman 0

    run "$func"

    [ "$status" -eq 0 ]
    [[ "$output" == *"$expected"* ]]
}

# Assert a function installs a missing package
# Usage: assert_package_install <function_name> <package_name> [expected_output_substring]
assert_package_install() {
    local func="$1"
    local pkg="$2"
    local expected="${3:-}"
    mock_command_conditional pacman "$pkg" 1 0

    run "$func"

    [ "$status" -eq 0 ]
    assert_mock_called "pacman"
}
