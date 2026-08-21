#!/usr/bin/env bash
# =============================================================================
# mise_plugin.bash — Contract tests for mise/asdf plugin env requirements
# =============================================================================
# shellcheck disable=SC2154  # $status is set by bats `run`

# Assert a plugin script errors when a required env var is unset
# Usage: assert_asdf_env_required <script_path> <env_var_name>
assert_asdf_env_required() {
    local script="$1"
    local var_name="$2"

    unset "$var_name"
    # Ensure sibling vars have sensible defaults
    export ASDF_DOWNLOAD_PATH="${ASDF_DOWNLOAD_PATH:-${TEST_TEMP}/download}"
    export ASDF_INSTALL_PATH="${ASDF_INSTALL_PATH:-${TEST_TEMP}/install}"
    export ASDF_INSTALL_VERSION="${ASDF_INSTALL_VERSION:-1.0.0}"

    # Now unset the one we're testing (in case the defaults above set it)
    unset "$var_name"

    run bash "$script"
    [ "$status" -ne 0 ]
}
