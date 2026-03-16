#!/usr/bin/env bash
# =============================================================================
# common.bash — Shared setup, teardown, and mock framework for bats tests
# =============================================================================

REPO_ROOT="$(cd "$(dirname "${BATS_TEST_FILENAME}")/.." && pwd)"
# shellcheck disable=SC2034  # Used by .bats files
SCRIPTS_DIR="${REPO_ROOT}/scripts"
# shellcheck disable=SC2034  # Used by .bats files
WORKSTATION_DIR="${REPO_ROOT}/workstation"

# ── Common setup/teardown (call from each .bats file) ────────────────────────

common_setup() {
    export MOCK_BIN="$(mktemp -d)"
    export TEST_HOME="$(mktemp -d)"
    export TEST_TEMP="$(mktemp -d)"
    export MOCK_CALLS="${TEST_TEMP}/mock_calls"
    mkdir -p "$MOCK_CALLS"

    # Temp filesystem for system paths
    mkdir -p "${TEST_TEMP}/etc/kernel"
    mkdir -p "${TEST_TEMP}/etc/sysctl.d"
    mkdir -p "${TEST_TEMP}/etc/tlp.d"
    mkdir -p "${TEST_TEMP}/etc/mbpfan"
    mkdir -p "${TEST_TEMP}/etc/thermald"
    mkdir -p "${TEST_TEMP}/etc/modprobe.d"
    mkdir -p "${TEST_TEMP}/etc/systemd/system"
    mkdir -p "${TEST_TEMP}/boot/EFI/refind"
    mkdir -p "${TEST_TEMP}/dev_mapper"
    mkdir -p "${TEST_TEMP}/lib/firmware/brcm"
    mkdir -p "${TEST_TEMP}/sys/power"
    mkdir -p "${TEST_TEMP}/sys/devices/platform"
    mkdir -p "${TEST_TEMP}/proc"

    # Default system state files
    echo "s2idle [deep]" > "${TEST_TEMP}/sys/power/mem_sleep"
    echo "quiet nowatchdog splash rw" > "${TEST_TEMP}/proc/cmdline"
    echo "UUID=test-uuid / btrfs rw,subvol=/@ 0 0" > "${TEST_TEMP}/etc/fstab"

    # Save original env
    export ORIGINAL_PATH="$PATH"
    export ORIGINAL_HOME="$HOME"

    # Set test env — mock bin first in PATH
    export PATH="${MOCK_BIN}:${PATH}"
    export HOME="$TEST_HOME"
    export USER="${USER:-testuser}"

    # Always mock sudo (just pass through)
    _create_sudo_mock

    # Mock getent to return the test home
    mock_command getent 0 "${USER}:x:1000:1000::${TEST_HOME}:/bin/bash"

    # Mock whoami
    mock_command whoami 0 "${USER}"
}

common_teardown() {
    export PATH="$ORIGINAL_PATH"
    export HOME="$ORIGINAL_HOME"
    rm -rf "$MOCK_BIN" "$TEST_HOME" "$TEST_TEMP"
}

# ── sudo mock (passes commands through without privilege) ─────────────────────

_create_sudo_mock() {
    cat > "${MOCK_BIN}/sudo" << ENDMOCK
#!/usr/bin/env bash
echo "\$*" >> "${MOCK_CALLS}/sudo"
"\$@"
ENDMOCK
    chmod +x "${MOCK_BIN}/sudo"
}

# ── Mock command helpers ──────────────────────────────────────────────────────

# Create a mock command
# Usage: mock_command <name> [exit_code] [output_string]
mock_command() {
    local cmd="$1"
    local exit_code="${2:-0}"
    local output="${3:-}"

    local output_file="${TEST_TEMP}/mock_output_${cmd}"
    rm -f "$output_file"
    [[ -n "$output" ]] && printf '%s\n' "$output" > "$output_file"

    cat > "${MOCK_BIN}/${cmd}" << ENDMOCK
#!/usr/bin/env bash
echo "\$*" >> "${MOCK_CALLS}/${cmd}"
[[ -f "${output_file}" ]] && cat "${output_file}"
exit ${exit_code}
ENDMOCK
    chmod +x "${MOCK_BIN}/${cmd}"
}

# Create a mock command that outputs multiple lines
# Usage: mock_command_multiline <name> <exit_code> <line1> <line2> ...
mock_command_multiline() {
    local cmd="$1"
    local exit_code="${2:-0}"
    shift 2

    local output_file="${TEST_TEMP}/mock_output_${cmd}"
    printf '%s\n' "$@" > "$output_file"

    cat > "${MOCK_BIN}/${cmd}" << ENDMOCK
#!/usr/bin/env bash
echo "\$*" >> "${MOCK_CALLS}/${cmd}"
cat "${output_file}"
exit ${exit_code}
ENDMOCK
    chmod +x "${MOCK_BIN}/${cmd}"
}

# Create a mock that behaves differently based on arguments
# Usage: mock_command_conditional <name> <match_pattern> <exit_if_match> <exit_if_no_match> [output_if_match]
mock_command_conditional() {
    local cmd="$1"
    local pattern="$2"
    local exit_match="${3:-0}"
    local exit_nomatch="${4:-1}"
    local output_match="${5:-}"

    cat > "${MOCK_BIN}/${cmd}" << ENDMOCK
#!/usr/bin/env bash
echo "\$*" >> "${MOCK_CALLS}/${cmd}"
if echo "\$*" | /usr/bin/grep -qF -- "${pattern}"; then
    ${output_match:+echo "${output_match}"}
    exit ${exit_match}
else
    exit ${exit_nomatch}
fi
ENDMOCK
    chmod +x "${MOCK_BIN}/${cmd}"
}

# ── Mock assertion helpers ────────────────────────────────────────────────────

assert_mock_called() {
    local cmd="$1"
    if [[ ! -f "${MOCK_CALLS}/${cmd}" ]]; then
        echo "FAIL: Expected '${cmd}' to be called, but it was not" >&2
        return 1
    fi
}

assert_mock_not_called() {
    local cmd="$1"
    if [[ -f "${MOCK_CALLS}/${cmd}" ]]; then
        echo "FAIL: Expected '${cmd}' NOT to be called. Actual calls:" >&2
        cat "${MOCK_CALLS}/${cmd}" >&2
        return 1
    fi
}

assert_mock_called_with() {
    local cmd="$1"
    shift
    local pattern="$*"
    if ! grep -q "$pattern" "${MOCK_CALLS}/${cmd}" 2>/dev/null; then
        echo "FAIL: Expected '${cmd}' to be called with '${pattern}'" >&2
        echo "Actual calls:" >&2
        cat "${MOCK_CALLS}/${cmd}" 2>/dev/null || echo "  (none)" >&2
        return 1
    fi
}

mock_call_count() {
    local cmd="$1"
    if [[ -f "${MOCK_CALLS}/${cmd}" ]]; then
        wc -l < "${MOCK_CALLS}/${cmd}"
    else
        echo 0
    fi
}

# ── Script sourcing helpers ───────────────────────────────────────────────────

# Prepare a script for sourcing: strip strict mode, entry points, redirect system paths
# Sets: SOURCEABLE_SCRIPT
prepare_script() {
    local script="$1"
    SOURCEABLE_SCRIPT="${TEST_TEMP}/sourceable_$(basename "$script")"

    sed \
        -e '/^set -[Ee]*uo pipefail$/d' \
        -e '/^main "\$@"$/d' \
        -e '/^case "\${1:-}" in$/,/^esac$/d' \
        -e 's/\[\[ \$EUID -eq 0 \]\] || error/true || error/g' \
        -e "s|/dev/mapper/|${TEST_TEMP}/dev_mapper/|g" \
        -e "s|/etc/|${TEST_TEMP}/etc/|g" \
        -e "s|/boot/|${TEST_TEMP}/boot/|g" \
        -e "s|/lib/firmware/|${TEST_TEMP}/lib/firmware/|g" \
        -e "s|/usr/share/|${TEST_TEMP}/usr/share/|g" \
        -e "s|/sys/power/|${TEST_TEMP}/sys/power/|g" \
        -e "s|/sys/devices/|${TEST_TEMP}/sys/devices/|g" \
        -e "s|/proc/cmdline|${TEST_TEMP}/proc/cmdline|g" \
        "$script" > "$SOURCEABLE_SCRIPT"

    # Neuter require_root for test environment (redefine after source)
    echo 'require_root() { true; }' >> "$SOURCEABLE_SCRIPT"
}

# Source a script's functions (call after common_setup)
source_script() {
    local script="$1"
    prepare_script "$script"
    # shellcheck disable=SC1090
    source "$SOURCEABLE_SCRIPT"
}

# Prepare a runnable version of a script (for scripts without functions)
# Sets: RUNNABLE_SCRIPT
prepare_runnable_script() {
    local script="$1"
    RUNNABLE_SCRIPT="${TEST_TEMP}/runnable_$(basename "$script")"

    sed \
        -e '/^set -[Ee]*uo pipefail$/d' \
        -e "s|/dev/mapper/|${TEST_TEMP}/dev_mapper/|g" \
        -e "s|/etc/|${TEST_TEMP}/etc/|g" \
        -e "s|/boot/|${TEST_TEMP}/boot/|g" \
        -e "s|/lib/firmware/|${TEST_TEMP}/lib/firmware/|g" \
        -e "s|/usr/share/|${TEST_TEMP}/usr/share/|g" \
        -e "s|/sys/power/|${TEST_TEMP}/sys/power/|g" \
        -e "s|/sys/devices/|${TEST_TEMP}/sys/devices/|g" \
        -e "s|/proc/cmdline|${TEST_TEMP}/proc/cmdline|g" \
        "$script" > "$RUNNABLE_SCRIPT"
    chmod +x "$RUNNABLE_SCRIPT"
}

# Run a sourced function with piped stdin (for interactive functions)
# Usage: run_with_input "input\nlines" function_name [args...]
run_with_input() {
    local input="$1"
    local func="$2"
    shift 2

    run bash -c "
        export PATH='${PATH}'
        export HOME='${HOME}'
        export MOCK_CALLS='${MOCK_CALLS}'
        export TEST_TEMP='${TEST_TEMP}'
        source '${SOURCEABLE_SCRIPT}'
        printf '%b' '${input}' | ${func} \"\$@\"
    " -- "$@"
}
