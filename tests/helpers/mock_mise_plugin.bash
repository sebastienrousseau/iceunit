#!/usr/bin/env bash
# =============================================================================
# mock_mise_plugin.bash — Shared helpers for mise plugin tests (ollama,
# claude-code, droid-factory). Extracted from 3 identical copies.
# =============================================================================

# Override uname to return specified OS and architecture
# Usage: mock_uname <os_name> <arch_name>
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

# Create a curl mock that records calls and touches the -o output file
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
