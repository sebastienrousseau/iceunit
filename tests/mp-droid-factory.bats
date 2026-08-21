#!/usr/bin/env bats

load test_helper

setup() {
    common_setup
    PLUGIN_DIR="${REPO_ROOT}/mise-plugins/droid-factory/bin"
}

teardown() { common_teardown; }

# ── Shebang ──────────────────────────────────────────────────────────────────

@test "droid-factory plugin: all scripts use #!/usr/bin/env bash" {
    for script in list-all download install; do
        head -1 "${PLUGIN_DIR}/${script}" | grep -q '#!/usr/bin/env bash'
    done
}

# ── list-all ─────────────────────────────────────────────────────────────────

@test "droid list-all: parses versions sorted oldest first" {
    mock_command curl 0 '{"version": "2.3.0"}, {"version": "2.1.0"}, {"version": "2.2.0"}'

    run bash "${PLUGIN_DIR}/list-all"
    [ "$status" -eq 0 ]
    [[ "$output" == *"2.1.0"* ]]
    [[ "$output" == *"2.2.0"* ]]
    [[ "$output" == *"2.3.0"* ]]
    local pos1 pos3
    pos1=$(echo "$output" | grep -bo '2\.1\.0' | head -1 | cut -d: -f1)
    pos3=$(echo "$output" | grep -bo '2\.3\.0' | head -1 | cut -d: -f1)
    [ "$pos1" -lt "$pos3" ]
}

# ── download ─────────────────────────────────────────────────────────────────

@test "droid download: errors without ASDF_INSTALL_VERSION" {
    assert_asdf_env_required "${PLUGIN_DIR}/download" ASDF_INSTALL_VERSION
}

@test "droid download: errors without ASDF_DOWNLOAD_PATH" {
    assert_asdf_env_required "${PLUGIN_DIR}/download" ASDF_DOWNLOAD_PATH
}

@test "droid download: uses Linux platform" {
    export ASDF_INSTALL_VERSION="2.0.0"
    export ASDF_DOWNLOAD_PATH="${TEST_TEMP}/download"
    mock_curl_download
    mock_uname "Linux" "x86_64"

    run bash "${PLUGIN_DIR}/download"
    [ "$status" -eq 0 ]
    assert_mock_called_with curl "linux"
    [[ "$output" == *"Downloading Droid v2.0.0"* ]]
    [[ "$output" == *"linux"* ]]
}

@test "droid download: uses macOS platform on Darwin" {
    export ASDF_INSTALL_VERSION="2.0.0"
    export ASDF_DOWNLOAD_PATH="${TEST_TEMP}/download"
    mock_curl_download
    mock_uname "Darwin" "arm64"

    run bash "${PLUGIN_DIR}/download"
    [ "$status" -eq 0 ]
    assert_mock_called_with curl "macos"
    [[ "$output" == *"macos"* ]]
}

@test "droid download: errors on unsupported OS" {
    export ASDF_INSTALL_VERSION="2.0.0"
    export ASDF_DOWNLOAD_PATH="${TEST_TEMP}/download"
    mock_uname "FreeBSD" "x86_64"

    run bash "${PLUGIN_DIR}/download" 2>&1
    [ "$status" -eq 1 ]
    [[ "$output" == *"Unsupported OS"* ]]
}

@test "droid download: sets executable permission on binary" {
    export ASDF_INSTALL_VERSION="2.0.0"
    export ASDF_DOWNLOAD_PATH="${TEST_TEMP}/download"
    mock_curl_download
    mock_uname "Linux" "x86_64"

    run bash "${PLUGIN_DIR}/download"
    [ "$status" -eq 0 ]
    [ -x "${ASDF_DOWNLOAD_PATH}/droid" ]
}

# ── install ──────────────────────────────────────────────────────────────────

@test "droid install: errors without ASDF_INSTALL_VERSION" {
    assert_asdf_env_required "${PLUGIN_DIR}/install" ASDF_INSTALL_VERSION
}

@test "droid install: errors without ASDF_INSTALL_PATH" {
    assert_asdf_env_required "${PLUGIN_DIR}/install" ASDF_INSTALL_PATH
}

@test "droid install: errors without ASDF_DOWNLOAD_PATH" {
    assert_asdf_env_required "${PLUGIN_DIR}/install" ASDF_DOWNLOAD_PATH
}

@test "droid install: copies binary and prints success" {
    export ASDF_INSTALL_VERSION="2.0.0"
    export ASDF_INSTALL_PATH="${TEST_TEMP}/install"
    export ASDF_DOWNLOAD_PATH="${TEST_TEMP}/download"
    mkdir -p "$ASDF_DOWNLOAD_PATH"

    printf '#!/bin/bash\necho "2.0.0"\n' > "${ASDF_DOWNLOAD_PATH}/droid"
    chmod +x "${ASDF_DOWNLOAD_PATH}/droid"

    run bash "${PLUGIN_DIR}/install"
    [ "$status" -eq 0 ]
    [[ "$output" == *"installed successfully"* ]]
    [ -x "${ASDF_INSTALL_PATH}/bin/droid" ]
}

@test "droid install: prints warning when version check fails" {
    export ASDF_INSTALL_VERSION="2.0.0"
    export ASDF_INSTALL_PATH="${TEST_TEMP}/install"
    export ASDF_DOWNLOAD_PATH="${TEST_TEMP}/download"
    mkdir -p "$ASDF_DOWNLOAD_PATH"

    printf '#!/bin/bash\nexit 1\n' > "${ASDF_DOWNLOAD_PATH}/droid"
    chmod +x "${ASDF_DOWNLOAD_PATH}/droid"

    run bash "${PLUGIN_DIR}/install" 2>&1
    [ "$status" -eq 0 ]
    [[ "$output" == *"Warning"* ]]
    [[ "$output" == *"version check failed"* ]]
}
