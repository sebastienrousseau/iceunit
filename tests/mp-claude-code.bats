#!/usr/bin/env bats

load test_helper

# ── Helpers ──────────────────────────────────────────────────────────────────

mock_uname() {
    local os_name="$1"
    local arch_name="$2"
    cat > "${MOCK_BIN}/uname" << ENDMOCK
#!/usr/bin/env bash
case "\$1" in
    -s) echo "${os_name}" ;;
    -m) echo "${arch_name}" ;;
    *) /usr/bin/uname "\$@" ;;
esac
ENDMOCK
    chmod +x "${MOCK_BIN}/uname"
}

mock_curl_download() {
    cat > "${MOCK_BIN}/curl" << 'ENDMOCK'
#!/usr/bin/env bash
echo "$*" >> "${MOCK_CALLS}/curl"
while [[ $# -gt 0 ]]; do
    case "$1" in
        -o) touch "$2"; shift ;;
    esac
    shift
done
ENDMOCK
    chmod +x "${MOCK_BIN}/curl"
}

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

@test "claude-code download: errors when ASDF_INSTALL_VERSION unset" {
    unset ASDF_INSTALL_VERSION
    export ASDF_DOWNLOAD_PATH="${TEST_TEMP}/download"

    run bash "${PLUGIN_DIR}/download"
    [ "$status" -ne 0 ]
}

@test "claude-code download: errors when ASDF_DOWNLOAD_PATH unset" {
    export ASDF_INSTALL_VERSION="1.0.0"
    unset ASDF_DOWNLOAD_PATH

    run bash "${PLUGIN_DIR}/download"
    [ "$status" -ne 0 ]
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

@test "claude-code install: errors when ASDF_INSTALL_VERSION unset" {
    unset ASDF_INSTALL_VERSION
    export ASDF_INSTALL_PATH="${TEST_TEMP}/install"
    export ASDF_DOWNLOAD_PATH="${TEST_TEMP}/download"

    run bash "${PLUGIN_DIR}/install"
    [ "$status" -ne 0 ]
}

@test "claude-code install: errors when ASDF_INSTALL_PATH unset" {
    export ASDF_INSTALL_VERSION="1.0.0"
    unset ASDF_INSTALL_PATH
    export ASDF_DOWNLOAD_PATH="${TEST_TEMP}/download"

    run bash "${PLUGIN_DIR}/install"
    [ "$status" -ne 0 ]
}

@test "claude-code install: errors when ASDF_DOWNLOAD_PATH unset" {
    export ASDF_INSTALL_VERSION="1.0.0"
    export ASDF_INSTALL_PATH="${TEST_TEMP}/install"
    unset ASDF_DOWNLOAD_PATH

    run bash "${PLUGIN_DIR}/install"
    [ "$status" -ne 0 ]
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
