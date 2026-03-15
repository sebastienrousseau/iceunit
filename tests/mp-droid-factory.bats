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

@test "droid download: errors when ASDF_INSTALL_VERSION unset" {
    unset ASDF_INSTALL_VERSION
    export ASDF_DOWNLOAD_PATH="${TEST_TEMP}/download"

    run bash "${PLUGIN_DIR}/download"
    [ "$status" -ne 0 ]
}

@test "droid download: errors when ASDF_DOWNLOAD_PATH unset" {
    export ASDF_INSTALL_VERSION="2.0.0"
    unset ASDF_DOWNLOAD_PATH

    run bash "${PLUGIN_DIR}/download"
    [ "$status" -ne 0 ]
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

@test "droid install: errors when ASDF_INSTALL_VERSION unset" {
    unset ASDF_INSTALL_VERSION
    export ASDF_INSTALL_PATH="${TEST_TEMP}/install"
    export ASDF_DOWNLOAD_PATH="${TEST_TEMP}/download"

    run bash "${PLUGIN_DIR}/install"
    [ "$status" -ne 0 ]
}

@test "droid install: errors when ASDF_INSTALL_PATH unset" {
    export ASDF_INSTALL_VERSION="2.0.0"
    unset ASDF_INSTALL_PATH
    export ASDF_DOWNLOAD_PATH="${TEST_TEMP}/download"

    run bash "${PLUGIN_DIR}/install"
    [ "$status" -ne 0 ]
}

@test "droid install: errors when ASDF_DOWNLOAD_PATH unset" {
    export ASDF_INSTALL_VERSION="2.0.0"
    export ASDF_INSTALL_PATH="${TEST_TEMP}/install"
    unset ASDF_DOWNLOAD_PATH

    run bash "${PLUGIN_DIR}/install"
    [ "$status" -ne 0 ]
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
