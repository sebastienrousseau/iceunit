#!/usr/bin/env bats

load test_helper

setup() {
    common_setup
    PLUGIN_DIR="${REPO_ROOT}/mise-plugins/claude-code/bin"
}

teardown() { common_teardown; }

# ── Shebang ──────────────────────────────────────────────────────────────────

@test "claude-code plugin: all scripts use #!/usr/bin/env bash" {
    for script in list-all download install; do
        head -1 "${PLUGIN_DIR}/${script}" | grep -q '#!/usr/bin/env bash'
    done
}

# ── list-all ─────────────────────────────────────────────────────────────────

@test "claude-code list-all: parses versions sorted oldest first" {
    mock_command curl 0 '{"version": "1.2.0"}, {"version": "1.0.0"}, {"version": "1.1.0"}'

    run bash "${PLUGIN_DIR}/list-all"
    [ "$status" -eq 0 ]
    [[ "$output" == *"1.0.0"* ]]
    [[ "$output" == *"1.1.0"* ]]
    [[ "$output" == *"1.2.0"* ]]
    # Verify sort order
    local pos1 pos2
    pos1=$(echo "$output" | grep -bo '1\.0\.0' | head -1 | cut -d: -f1)
    pos2=$(echo "$output" | grep -bo '1\.2\.0' | head -1 | cut -d: -f1)
    [ "$pos1" -lt "$pos2" ]
}

# ── download ─────────────────────────────────────────────────────────────────

@test "claude-code download: errors without ASDF_INSTALL_VERSION" {
    assert_asdf_env_required "${PLUGIN_DIR}/download" ASDF_INSTALL_VERSION
}

@test "claude-code download: errors without ASDF_DOWNLOAD_PATH" {
    assert_asdf_env_required "${PLUGIN_DIR}/download" ASDF_DOWNLOAD_PATH
}

@test "claude-code download: maps x86_64 to x64 in URL" {
    export ASDF_INSTALL_VERSION="1.0.0"
    export ASDF_DOWNLOAD_PATH="${TEST_TEMP}/download"
    mock_curl_download
    mock_command tar 0
    mock_uname "Linux" "x86_64"

    run bash "${PLUGIN_DIR}/download"
    [ "$status" -eq 0 ]
    assert_mock_called_with curl "claude-linux-x64-1.0.0.tar.gz"
    [[ "$output" == *"Downloading Claude Code v1.0.0"* ]]
}

@test "claude-code download: maps aarch64 to arm64 in URL" {
    export ASDF_INSTALL_VERSION="1.0.0"
    export ASDF_DOWNLOAD_PATH="${TEST_TEMP}/download"
    mock_curl_download
    mock_command tar 0
    mock_uname "Linux" "aarch64"

    run bash "${PLUGIN_DIR}/download"
    [ "$status" -eq 0 ]
    assert_mock_called_with curl "claude-linux-arm64-1.0.0.tar.gz"
}

@test "claude-code download: extracts tarball after download" {
    export ASDF_INSTALL_VERSION="1.0.0"
    export ASDF_DOWNLOAD_PATH="${TEST_TEMP}/download"
    mock_curl_download
    mock_command tar 0
    mock_uname "Linux" "x86_64"

    run bash "${PLUGIN_DIR}/download"
    [ "$status" -eq 0 ]
    assert_mock_called tar
    [[ "$output" == *"Downloaded to"* ]]
}

# ── install ──────────────────────────────────────────────────────────────────

@test "claude-code install: errors without ASDF_INSTALL_VERSION" {
    assert_asdf_env_required "${PLUGIN_DIR}/install" ASDF_INSTALL_VERSION
}

@test "claude-code install: errors without ASDF_INSTALL_PATH" {
    assert_asdf_env_required "${PLUGIN_DIR}/install" ASDF_INSTALL_PATH
}

@test "claude-code install: errors without ASDF_DOWNLOAD_PATH" {
    assert_asdf_env_required "${PLUGIN_DIR}/install" ASDF_DOWNLOAD_PATH
}

@test "claude-code install: copies binary and prints success" {
    export ASDF_INSTALL_VERSION="1.0.0"
    export ASDF_INSTALL_PATH="${TEST_TEMP}/install"
    export ASDF_DOWNLOAD_PATH="${TEST_TEMP}/download"
    mkdir -p "$ASDF_DOWNLOAD_PATH"

    # Create a working fake binary in download path
    printf '#!/bin/bash\necho "1.0.0"\n' > "${ASDF_DOWNLOAD_PATH}/claude"
    chmod +x "${ASDF_DOWNLOAD_PATH}/claude"

    run bash "${PLUGIN_DIR}/install"
    [ "$status" -eq 0 ]
    [[ "$output" == *"installed successfully"* ]]
    # Verify binary was copied to install path
    [ -x "${ASDF_INSTALL_PATH}/bin/claude" ]
}

@test "claude-code install: prints warning when version check fails" {
    export ASDF_INSTALL_VERSION="1.0.0"
    export ASDF_INSTALL_PATH="${TEST_TEMP}/install"
    export ASDF_DOWNLOAD_PATH="${TEST_TEMP}/download"
    mkdir -p "$ASDF_DOWNLOAD_PATH"

    # Create a binary that exits non-zero
    printf '#!/bin/bash\nexit 1\n' > "${ASDF_DOWNLOAD_PATH}/claude"
    chmod +x "${ASDF_DOWNLOAD_PATH}/claude"

    run bash "${PLUGIN_DIR}/install" 2>&1
    [ "$status" -eq 0 ]
    [[ "$output" == *"Warning"* ]]
    [[ "$output" == *"version check failed"* ]]
}
