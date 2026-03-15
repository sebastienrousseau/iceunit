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
    PLUGIN_DIR="${REPO_ROOT}/mise-plugins/ollama/bin"
}

teardown() { common_teardown; }

# ── Shebang ──────────────────────────────────────────────────────────────────

@test "ollama plugin: all scripts use #!/usr/bin/env bash" {
    for script in list-all download install; do
        head -1 "${PLUGIN_DIR}/${script}" | grep -q '#!/usr/bin/env bash'
    done
}

# ── list-all ─────────────────────────────────────────────────────────────────

@test "ollama list-all: parses versions sorted oldest first" {
    mock_command curl 0 '{"name": "v0.3.0"}, {"name": "v0.1.0"}, {"name": "v0.2.0"}'

    run bash "${PLUGIN_DIR}/list-all"
    [ "$status" -eq 0 ]
    [[ "$output" == *"0.1.0"* ]]
    [[ "$output" == *"0.2.0"* ]]
    [[ "$output" == *"0.3.0"* ]]
    # Verify sort order: 0.1.0 appears before 0.3.0
    local pos1 pos3
    pos1=$(echo "$output" | grep -bo '0\.1\.0' | head -1 | cut -d: -f1)
    pos3=$(echo "$output" | grep -bo '0\.3\.0' | head -1 | cut -d: -f1)
    [ "$pos1" -lt "$pos3" ]
}

@test "ollama list-all: includes auth header when GITHUB_API_TOKEN set" {
    export GITHUB_API_TOKEN="test-token-123"
    mock_command curl 0 '{"name": "v0.1.0"}'

    run bash "${PLUGIN_DIR}/list-all"
    [ "$status" -eq 0 ]
    assert_mock_called_with curl "Authorization: token test-token-123"
}

@test "ollama list-all: omits auth header without GITHUB_API_TOKEN" {
    unset GITHUB_API_TOKEN
    mock_command curl 0 '{"name": "v0.1.0"}'

    run bash "${PLUGIN_DIR}/list-all"
    [ "$status" -eq 0 ]
    # Verify no Authorization header in curl args
    local curl_args
    curl_args=$(cat "${MOCK_CALLS}/curl")
    [[ "$curl_args" != *"Authorization"* ]]
}

# ── download ─────────────────────────────────────────────────────────────────

@test "ollama download: errors when ASDF_INSTALL_VERSION unset" {
    unset ASDF_INSTALL_VERSION
    export ASDF_DOWNLOAD_PATH="${TEST_TEMP}/download"

    run bash "${PLUGIN_DIR}/download"
    [ "$status" -ne 0 ]
}

@test "ollama download: errors when ASDF_DOWNLOAD_PATH unset" {
    export ASDF_INSTALL_VERSION="0.5.0"
    unset ASDF_DOWNLOAD_PATH

    run bash "${PLUGIN_DIR}/download"
    [ "$status" -ne 0 ]
}

@test "ollama download: downloads Linux amd64 archive" {
    export ASDF_INSTALL_VERSION="0.5.0"
    export ASDF_DOWNLOAD_PATH="${TEST_TEMP}/download"
    mock_curl_download
    mock_uname "Linux" "x86_64"

    run bash "${PLUGIN_DIR}/download"
    [ "$status" -eq 0 ]
    assert_mock_called_with curl "ollama-linux-amd64.tgz"
    [[ "$output" == *"Downloading Ollama 0.5.0"* ]]
    [[ "$output" == *"Downloaded to"* ]]
}

@test "ollama download: maps aarch64 to arm64" {
    export ASDF_INSTALL_VERSION="0.5.0"
    export ASDF_DOWNLOAD_PATH="${TEST_TEMP}/download"
    mock_curl_download
    mock_uname "Linux" "aarch64"

    run bash "${PLUGIN_DIR}/download"
    [ "$status" -eq 0 ]
    assert_mock_called_with curl "ollama-linux-arm64.tgz"
}

@test "ollama download: downloads Darwin archive" {
    export ASDF_INSTALL_VERSION="0.5.0"
    export ASDF_DOWNLOAD_PATH="${TEST_TEMP}/download"
    mock_curl_download
    mock_uname "Darwin" "arm64"

    run bash "${PLUGIN_DIR}/download"
    [ "$status" -eq 0 ]
    assert_mock_called_with curl "Ollama-darwin.zip"
}

@test "ollama download: errors on unsupported OS" {
    export ASDF_INSTALL_VERSION="0.5.0"
    export ASDF_DOWNLOAD_PATH="${TEST_TEMP}/download"
    mock_uname "FreeBSD" "x86_64"

    run bash "${PLUGIN_DIR}/download" 2>&1
    [ "$status" -eq 1 ]
    [[ "$output" == *"Unsupported OS"* ]]
}

# ── install ──────────────────────────────────────────────────────────────────

@test "ollama install: errors when ASDF_INSTALL_VERSION unset" {
    unset ASDF_INSTALL_VERSION
    export ASDF_INSTALL_PATH="${TEST_TEMP}/install"
    export ASDF_DOWNLOAD_PATH="${TEST_TEMP}/download"

    run bash "${PLUGIN_DIR}/install"
    [ "$status" -ne 0 ]
}

@test "ollama install: errors when ASDF_INSTALL_PATH unset" {
    export ASDF_INSTALL_VERSION="0.5.0"
    unset ASDF_INSTALL_PATH
    export ASDF_DOWNLOAD_PATH="${TEST_TEMP}/download"

    run bash "${PLUGIN_DIR}/install"
    [ "$status" -ne 0 ]
}

@test "ollama install: errors when ASDF_DOWNLOAD_PATH unset" {
    export ASDF_INSTALL_VERSION="0.5.0"
    export ASDF_INSTALL_PATH="${TEST_TEMP}/install"
    unset ASDF_DOWNLOAD_PATH

    run bash "${PLUGIN_DIR}/install"
    [ "$status" -ne 0 ]
}

@test "ollama install: extracts via tar on Linux" {
    export ASDF_INSTALL_VERSION="0.5.0"
    export ASDF_INSTALL_PATH="${TEST_TEMP}/install"
    export ASDF_DOWNLOAD_PATH="${TEST_TEMP}/download"
    mock_command tar 0
    mock_uname "Linux" "x86_64"

    # Pre-create fake binary for version check
    mkdir -p "${ASDF_INSTALL_PATH}/bin"
    printf '#!/bin/bash\necho "0.5.0"\n' > "${ASDF_INSTALL_PATH}/bin/ollama"
    chmod +x "${ASDF_INSTALL_PATH}/bin/ollama"

    run bash "${PLUGIN_DIR}/install"
    [ "$status" -eq 0 ]
    assert_mock_called tar
    assert_mock_called_with tar "ollama-linux-amd64.tgz"
}

@test "ollama install: uses unzip on Darwin" {
    export ASDF_INSTALL_VERSION="0.5.0"
    export ASDF_INSTALL_PATH="${TEST_TEMP}/install"
    export ASDF_DOWNLOAD_PATH="${TEST_TEMP}/download"
    mock_command unzip 0
    mock_uname "Darwin" "arm64"

    mkdir -p "${ASDF_INSTALL_PATH}/bin"
    printf '#!/bin/bash\necho "0.5.0"\n' > "${ASDF_INSTALL_PATH}/bin/ollama"
    chmod +x "${ASDF_INSTALL_PATH}/bin/ollama"

    run bash "${PLUGIN_DIR}/install"
    [ "$status" -eq 0 ]
    assert_mock_called unzip
    assert_mock_called_with unzip "Ollama-darwin.zip"
}

@test "ollama install: prints success when version check passes" {
    export ASDF_INSTALL_VERSION="0.5.0"
    export ASDF_INSTALL_PATH="${TEST_TEMP}/install"
    export ASDF_DOWNLOAD_PATH="${TEST_TEMP}/download"
    mock_command tar 0
    mock_uname "Linux" "x86_64"

    mkdir -p "${ASDF_INSTALL_PATH}/bin"
    printf '#!/bin/bash\necho "0.5.0"\n' > "${ASDF_INSTALL_PATH}/bin/ollama"
    chmod +x "${ASDF_INSTALL_PATH}/bin/ollama"

    run bash "${PLUGIN_DIR}/install"
    [ "$status" -eq 0 ]
    [[ "$output" == *"installed successfully"* ]]
}

@test "ollama install: prints warning when version check fails" {
    export ASDF_INSTALL_VERSION="0.5.0"
    export ASDF_INSTALL_PATH="${TEST_TEMP}/install"
    export ASDF_DOWNLOAD_PATH="${TEST_TEMP}/download"
    mock_command tar 0
    mock_uname "Linux" "x86_64"

    # Don't create a binary — version check will fail
    run bash "${PLUGIN_DIR}/install" 2>&1
    [ "$status" -eq 0 ]
    [[ "$output" == *"Warning"* ]]
    [[ "$output" == *"version check failed"* ]]
}

@test "ollama install: errors on unsupported OS" {
    export ASDF_INSTALL_VERSION="0.5.0"
    export ASDF_INSTALL_PATH="${TEST_TEMP}/install"
    export ASDF_DOWNLOAD_PATH="${TEST_TEMP}/download"
    mock_uname "FreeBSD" "x86_64"

    run bash "${PLUGIN_DIR}/install" 2>&1
    [ "$status" -eq 1 ]
    [[ "$output" == *"Unsupported OS"* ]]
}
