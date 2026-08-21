#!/usr/bin/env bats
# Tests for workstation/05-desktop-base.sh

load test_helper

setup() {
    common_setup
    source_script "$WORKSTATION_DIR/05-desktop-base.sh"

    # Mock commands that require hardware/root/packages
    mock_command pacman 0
    mock_command systemctl 0
    mock_command xdg-user-dirs-update 0
}

teardown() {
    common_teardown
}

# ── install_desktop ──────────────────────────────────────────────────────────

@test "desktop: skips when gnome and gdm installed" {
    assert_package_skip install_desktop "already installed"
}

@test "desktop: installs missing packages" {
    assert_package_install install_desktop gnome
}

# ── setup_networkmanager ─────────────────────────────────────────────────────

@test "networkmanager: skips when already installed and enabled" {
    mock_command pacman 0
    mock_service_enabled NetworkManager

    run setup_networkmanager

    [ "$status" -eq 0 ]
    [[ "$output" == *"already installed"* ]]
}

@test "networkmanager: installs when missing" {
    mock_package_missing networkmanager

    run setup_networkmanager

    [ "$status" -eq 0 ]
    [[ "$output" == *"Installing NetworkManager"* ]]
}

# ── setup_audio ──────────────────────────────────────────────────────────────

@test "audio: skips when PipeWire already installed" {
    assert_package_skip setup_audio "already installed"
}

@test "audio: installs missing PipeWire packages" {
    mock_package_missing pipewire-pulse

    run setup_audio

    [ "$status" -eq 0 ]
    [[ "$output" == *"Installing PipeWire"* ]]
}

# ── setup_xdg_dirs ───────────────────────────────────────────────────────────

@test "xdg dirs: skips install when already present" {
    assert_package_skip setup_xdg_dirs "already installed"
}

@test "xdg dirs: runs xdg-user-dirs-update for real user" {
    mock_command pacman 0
    export SUDO_USER="testuser"

    run setup_xdg_dirs

    [ "$status" -eq 0 ]
    [[ "$output" == *"Initialising XDG directories"* ]]
}

@test "xdg dirs: installs when missing" {
    mock_package_missing xdg-user-dirs

    run setup_xdg_dirs

    [ "$status" -eq 0 ]
    [[ "$output" == *"Installing xdg-user-dirs"* ]]
}

# ── install_fonts ────────────────────────────────────────────────────────────

@test "fonts: skips when all present" {
    assert_package_skip install_fonts "already installed"
}

@test "fonts: installs missing font packages" {
    assert_package_install install_fonts noto-fonts-emoji
}

# ── setup_fwupd ──────────────────────────────────────────────────────────────

@test "fwupd: skips when already installed and enabled" {
    mock_command pacman 0
    mock_service_enabled fwupd.service

    run setup_fwupd

    [ "$status" -eq 0 ]
    [[ "$output" == *"already installed"* ]]
}

@test "fwupd: installs when missing" {
    mock_package_missing fwupd

    run setup_fwupd

    [ "$status" -eq 0 ]
    [[ "$output" == *"Installing fwupd"* ]]
}

# ── install_microcode ────────────────────────────────────────────────────────

@test "microcode: skips when already installed" {
    assert_package_skip install_microcode "already installed"
}

@test "microcode: installs intel-ucode when missing" {
    mock_package_missing intel-ucode

    run install_microcode

    [ "$status" -eq 0 ]
    [[ "$output" == *"Installing Intel CPU microcode"* ]]
}

# ── setup_maintenance_utils ──────────────────────────────────────────────────

@test "maintenance utils: skips when pacman-contrib installed" {
    assert_package_skip setup_maintenance_utils "already installed"
}

@test "maintenance utils: installs pacman-contrib when missing" {
    mock_package_missing pacman-contrib

    run setup_maintenance_utils

    [ "$status" -eq 0 ]
    [[ "$output" == *"Installing pacman-contrib"* ]]
}

# ── enable_timers ────────────────────────────────────────────────────────────

@test "timers: skips fstrim.timer when already enabled" {
    assert_service_skip_when_enabled enable_timers fstrim.timer "fstrim.timer already enabled"
}

@test "timers: enables fstrim.timer when not enabled" {
    assert_service_enables_when_disabled enable_timers fstrim.timer "Enabling fstrim.timer"
}

# ── enable_bluetooth ─────────────────────────────────────────────────────────

@test "bluetooth: skips when already installed and enabled" {
    mock_command pacman 0
    mock_service_enabled bluetooth

    run enable_bluetooth

    [ "$status" -eq 0 ]
    [[ "$output" == *"already installed"* ]]
}

@test "bluetooth: installs bluez when missing" {
    mock_package_missing bluez

    run enable_bluetooth

    [ "$status" -eq 0 ]
    [[ "$output" == *"Installing bluez"* ]]
}

# ── enable_gdm ───────────────────────────────────────────────────────────────

@test "gdm: skips when already enabled" {
    mock_command pacman 0
    mock_service_enabled gdm

    run enable_gdm

    [ "$status" -eq 0 ]
    [[ "$output" == *"already enabled"* ]]
}

@test "gdm: skips when not installed" {
    mock_package_missing gdm

    run enable_gdm

    [ "$status" -eq 0 ]
    [[ "$output" == *"not installed"* ]] || [[ "$output" == *"skipped"* ]]
}

# ── print_summary ────────────────────────────────────────────────────────────

@test "summary: shows applied items" {
    assert_summary_shows_items "fonts,microcode" "desktop-environment"
}

# ── dry-run end-to-end ───────────────────────────────────────────────────────

@test "desktop-base: runs in dry-run mode without error" {
    prepare_runnable_script "$WORKSTATION_DIR/05-desktop-base.sh"
    mock_command pacman 1
    assert_dry_run_succeeds
}

@test "desktop-base: --help shows usage" {
    prepare_runnable_script "$WORKSTATION_DIR/05-desktop-base.sh"
    assert_help_shows_usage
}

# ── shebang and standards ───────────────────────────────────────────────────

@test "desktop-base: uses #!/usr/bin/env bash" {
    assert_shebang "$WORKSTATION_DIR/05-desktop-base.sh"
}

@test "desktop-base: no emoji in output" {
    assert_no_emoji "$WORKSTATION_DIR/05-desktop-base.sh"
}
