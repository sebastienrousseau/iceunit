#!/usr/bin/env bats
# Tests for scripts/01-thermal-setup.sh

load test_helper

setup() {
    common_setup
    source_script "$SCRIPTS_DIR/01-thermal-setup.sh"

    # Only mock commands that require hardware/root/packages
    mock_command sensors 0 "Package id 0: +55.0°C"
    mock_command pacman 0
    mock_command systemctl 0
    mock_command sleep 0
    mock_command su 0
    mock_command paru 0
    mock_command yay 0
}

teardown() {
    common_teardown
}

# ── require_root ─────────────────────────────────────────────────────────────

@test "require_root: fails when not root" {
    # Source the original require_root (before our test override)
    local orig_script="${TEST_TEMP}/orig_01.sh"
    sed -e '/^set -euo pipefail$/d' -e '/^main "\$@"$/d' "$SCRIPTS_DIR/01-thermal-setup.sh" > "$orig_script"

    run bash -c "source '$orig_script'; require_root"

    [ "$status" -eq 1 ]
    [[ "$output" == *"Run with sudo"* ]]
}

# ── preflight ────────────────────────────────────────────────────────────────

@test "preflight: finds applesmc at platform path" {
    local smc_dir="${TEST_TEMP}/sys/devices/platform/applesmc.768"
    mkdir -p "$smc_dir"
    echo "3500" > "$smc_dir/fan1_output"

    run preflight

    [ "$status" -eq 0 ]
    [[ "$output" == *"Apple fan device found"* ]]
}

@test "preflight: warns when no SMC path found" {
    # Don't create any applesmc directories — find returns nothing

    run preflight

    [ "$status" -eq 0 ]
    [[ "$output" == *"not found"* ]]
}

@test "preflight: shows fan speed when file exists" {
    local smc_dir="${TEST_TEMP}/sys/devices/platform/applesmc.768"
    mkdir -p "$smc_dir"
    echo "4200" > "$smc_dir/fan1_output"

    run preflight

    [ "$status" -eq 0 ]
    [[ "$output" == *"4200"* ]]
}

@test "preflight: handles missing sensors gracefully" {
    mock_command sensors 1

    run preflight

    [ "$status" -eq 0 ]
}

# ── install_mbpfan ───────────────────────────────────────────────────────────

@test "install_mbpfan: skips if already installed" {
    assert_package_skip install_mbpfan "already installed"
}

@test "install_mbpfan: installs with paru" {
    mock_command pacman 1  # not installed
    SUDO_USER="testuser"

    run install_mbpfan

    [ "$status" -eq 0 ]
    [[ "$output" == *"mbpfan installed"* ]]
}

@test "install_mbpfan: installs with yay when paru unavailable" {
    mock_command pacman 1
    rm -f "${MOCK_BIN}/paru"
    SUDO_USER="testuser"

    run install_mbpfan

    [ "$status" -eq 0 ]
    [[ "$output" == *"mbpfan installed"* ]]
}

@test "install_mbpfan: errors when no AUR helper found" {
    mock_command pacman 1
    rm -f "${MOCK_BIN}/paru" "${MOCK_BIN}/yay"
    export PATH="${MOCK_BIN}"

    run install_mbpfan

    [ "$status" -eq 1 ]
    [[ "$output" == *"No AUR helper"* ]]
}

# ── configure_mbpfan ────────────────────────────────────────────────────────

@test "configure_mbpfan: writes config file" {
    run configure_mbpfan

    [ "$status" -eq 0 ]
    [[ "$output" == *"Config written"* ]]
    [ -f "${TEST_TEMP}/etc/mbpfan.conf" ]
}

@test "configure_mbpfan: config contains correct fan curve values" {
    run configure_mbpfan

    grep -q "min_speed = 2700" "${TEST_TEMP}/etc/mbpfan.conf"
    grep -q "max_speed = 8000" "${TEST_TEMP}/etc/mbpfan.conf"
    grep -q "low_temp        = 55" "${TEST_TEMP}/etc/mbpfan.conf"
    grep -q "high_temp       = 80" "${TEST_TEMP}/etc/mbpfan.conf"
    grep -q "max_temp        = 85" "${TEST_TEMP}/etc/mbpfan.conf"
    grep -q "temp_change_factor = 4" "${TEST_TEMP}/etc/mbpfan.conf"
}

@test "configure_mbpfan: backs up existing config" {
    echo "old config" > "${TEST_TEMP}/etc/mbpfan.conf"

    run configure_mbpfan

    [ -f "${TEST_TEMP}/etc/mbpfan.conf.bak" ]
    grep -q "old config" "${TEST_TEMP}/etc/mbpfan.conf.bak"
}

# ── handle_thermald ──────────────────────────────────────────────────────────

@test "handle_thermald: creates RAPL-only config when none exists" {
    run handle_thermald

    [ "$status" -eq 0 ]
    [ -f "${TEST_TEMP}/etc/thermald/thermal-conf.xml" ]
    grep -q "rapl_controller" "${TEST_TEMP}/etc/thermald/thermal-conf.xml"
}

@test "handle_thermald: does not overwrite existing xml" {
    echo "<existing/>" > "${TEST_TEMP}/etc/thermald/thermal-conf.xml"

    run handle_thermald

    [ "$status" -eq 0 ]
    [[ "$output" == *"already exists"* ]]
    grep -q "<existing/>" "${TEST_TEMP}/etc/thermald/thermal-conf.xml"
}

@test "handle_thermald: config excludes fan cooling devices" {
    run handle_thermald

    # Should only reference rapl_controller, not fan
    grep -q "rapl_controller" "${TEST_TEMP}/etc/thermald/thermal-conf.xml"
    ! grep -q "fan" "${TEST_TEMP}/etc/thermald/thermal-conf.xml" || \
        ! grep -q "<type>fan</type>" "${TEST_TEMP}/etc/thermald/thermal-conf.xml"
}

# ── enable_services ──────────────────────────────────────────────────────────

@test "enable_services: enables mbpfan" {
    # systemctl is-active returns success
    mock_command_conditional systemctl "is-active mbpfan" 0 0

    run enable_services

    [ "$status" -eq 0 ]
    [[ "$output" == *"mbpfan is active"* ]]
}

@test "enable_services: errors when mbpfan fails to start" {
    mock_command_conditional systemctl "is-active mbpfan" 1 0

    run enable_services

    [ "$status" -eq 1 ]
    [[ "$output" == *"failed to start"* ]]
}

# ── verify ───────────────────────────────────────────────────────────────────

@test "verify: shows completion message" {
    # Create a fan path so the function can check
    APPLESMC_PATH=""

    run verify

    [ "$status" -eq 0 ]
    [[ "$output" == *"Thermal setup complete"* ]]
}

@test "verify: shows fan speed when path available" {
    local smc_dir="${TEST_TEMP}/sys/devices/platform/applesmc.768"
    mkdir -p "$smc_dir"
    echo "5500" > "$smc_dir/fan1_output"
    APPLESMC_PATH="$smc_dir"

    run verify

    [ "$status" -eq 0 ]
    [[ "$output" == *"5500"* ]]
}

# ── shebang and standards ───────────────────────────────────────────────────

@test "thermal setup: uses #!/usr/bin/env bash" {
    assert_shebang "$SCRIPTS_DIR/01-thermal-setup.sh"
}

@test "thermal setup: no emoji in output" {
    assert_no_emoji "$SCRIPTS_DIR/01-thermal-setup.sh"
}
