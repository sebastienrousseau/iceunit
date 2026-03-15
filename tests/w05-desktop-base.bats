#!/usr/bin/env bats
# Tests for workstation/05-desktop-base.sh

load test_helper

setup() {
    common_setup
    source_script "$WORKSTATION_DIR/05-desktop-base.sh"

    # Mock commands that require hardware/root/packages
    mock_command pacman 0
    mock_command systemctl 0
    mock_command gdm 0
}

teardown() {
    common_teardown
}

# ── install_desktop ──────────────────────────────────────────────────────────

@test "desktop: skips when gnome and gdm installed" {
    mock_command pacman 0

    run install_desktop

    [ "$status" -eq 0 ]
    [[ "$output" == *"already installed"* ]]
}

@test "desktop: installs missing packages" {
    mock_command_conditional pacman "gnome" 1 0

    run install_desktop

    [ "$status" -eq 0 ]
    assert_mock_called "pacman"
}

# ── setup_networkmanager ─────────────────────────────────────────────────────

@test "networkmanager: skips when already installed and enabled" {
    mock_command pacman 0
    mock_command_conditional systemctl "is-enabled NetworkManager" 0 0

    run setup_networkmanager

    [ "$status" -eq 0 ]
    [[ "$output" == *"already installed"* ]]
}

@test "networkmanager: installs when missing" {
    mock_command_conditional pacman "networkmanager" 1 0

    run setup_networkmanager

    [ "$status" -eq 0 ]
    [[ "$output" == *"Installing NetworkManager"* ]]
}

# ── setup_xdg_dirs ───────────────────────────────────────────────────────────

@test "xdg dirs: skips when already installed" {
    mock_command pacman 0

    run setup_xdg_dirs

    [ "$status" -eq 0 ]
    [[ "$output" == *"already installed"* ]]
}

@test "xdg dirs: installs when missing" {
    mock_command_conditional pacman "xdg-user-dirs" 1 0

    run setup_xdg_dirs

    [ "$status" -eq 0 ]
    [[ "$output" == *"Installing xdg-user-dirs"* ]]
}

# ── install_fonts ────────────────────────────────────────────────────────────

@test "fonts: skips when all present" {
    mock_command pacman 0

    run install_fonts

    [ "$status" -eq 0 ]
    [[ "$output" == *"already installed"* ]]
}

@test "fonts: installs missing font packages" {
    mock_command_conditional pacman "noto-fonts-emoji" 1 0

    run install_fonts

    [ "$status" -eq 0 ]
    assert_mock_called "pacman"
}

# ── setup_fwupd ──────────────────────────────────────────────────────────────

@test "fwupd: skips when already installed and enabled" {
    mock_command pacman 0
    mock_command_conditional systemctl "is-enabled fwupd" 0 0

    run setup_fwupd

    [ "$status" -eq 0 ]
    [[ "$output" == *"already installed"* ]]
}

@test "fwupd: installs when missing" {
    mock_command_conditional pacman "fwupd" 1 0

    run setup_fwupd

    [ "$status" -eq 0 ]
    [[ "$output" == *"Installing fwupd"* ]]
}

# ── install_microcode ────────────────────────────────────────────────────────

@test "microcode: skips when already installed" {
    mock_command pacman 0

    run install_microcode

    [ "$status" -eq 0 ]
    [[ "$output" == *"already installed"* ]]
}

@test "microcode: installs intel-ucode when missing" {
    mock_command_conditional pacman "intel-ucode" 1 0

    run install_microcode

    [ "$status" -eq 0 ]
    [[ "$output" == *"Installing Intel CPU microcode"* ]]
}

# ── setup_maintenance_utils ──────────────────────────────────────────────────

@test "maintenance utils: skips when pacman-contrib installed" {
    mock_command pacman 0

    run setup_maintenance_utils

    [ "$status" -eq 0 ]
    [[ "$output" == *"already installed"* ]]
}

@test "maintenance utils: installs pacman-contrib when missing" {
    mock_command_conditional pacman "pacman-contrib" 1 0

    run setup_maintenance_utils

    [ "$status" -eq 0 ]
    [[ "$output" == *"Installing pacman-contrib"* ]]
}

# ── enable_timers ────────────────────────────────────────────────────────────

@test "timers: skips fstrim.timer when already enabled" {
    mock_command_conditional systemctl "is-enabled fstrim.timer" 0 0

    run enable_timers

    [ "$status" -eq 0 ]
    [[ "$output" == *"fstrim.timer already enabled"* ]]
}

@test "timers: enables fstrim.timer when not enabled" {
    mock_command_conditional systemctl "is-enabled fstrim.timer" 1 0

    run enable_timers

    [ "$status" -eq 0 ]
    [[ "$output" == *"Enabling fstrim.timer"* ]]
}

# ── enable_bluetooth ─────────────────────────────────────────────────────────

@test "bluetooth: skips when already installed and enabled" {
    mock_command pacman 0
    mock_command_conditional systemctl "is-enabled bluetooth" 0 0

    run enable_bluetooth

    [ "$status" -eq 0 ]
    [[ "$output" == *"already installed"* ]]
}

@test "bluetooth: installs bluez when missing" {
    mock_command_conditional pacman "bluez" 1 0

    run enable_bluetooth

    [ "$status" -eq 0 ]
    [[ "$output" == *"Installing bluez"* ]]
}

# ── enable_gdm ───────────────────────────────────────────────────────────────

@test "gdm: skips when already enabled" {
    mock_command pacman 0
    mock_command_conditional systemctl "is-enabled gdm" 0 0

    run enable_gdm

    [ "$status" -eq 0 ]
    [[ "$output" == *"already enabled"* ]]
}

@test "gdm: skips when not installed" {
    rm -f "${MOCK_BIN}/gdm"
    ln -sf /usr/bin/bash "${MOCK_BIN}/bash"
    mock_command_conditional pacman "gdm" 1 0

    run bash -c "
        export PATH='${MOCK_BIN}'
        export HOME='${HOME}'
        export MOCK_CALLS='${MOCK_CALLS}'
        export TEST_TEMP='${TEST_TEMP}'
        source '${SOURCEABLE_SCRIPT}'
        enable_gdm
    "

    [ "$status" -eq 0 ]
    [[ "$output" == *"not installed"* ]] || [[ "$output" == *"skipped"* ]]
}

# ── print_summary ────────────────────────────────────────────────────────────

@test "summary: shows applied items" {
    APPLIED=("fonts" "microcode")
    SKIPPED=("desktop-environment")

    run print_summary

    [ "$status" -eq 0 ]
    [[ "$output" == *"fonts"* ]]
    [[ "$output" == *"desktop-environment"* ]]
    [[ "$output" == *"complete"* ]]
}

# ── dry-run end-to-end ───────────────────────────────────────────────────────

@test "desktop-base: runs in dry-run mode without error" {
    prepare_runnable_script "$WORKSTATION_DIR/05-desktop-base.sh"
    # Mock pacman to fail so packages appear missing and DRY-RUN output shows
    mock_command pacman 1

    run bash "$RUNNABLE_SCRIPT" --dry-run

    [ "$status" -eq 0 ]
    [[ "$output" == *"DRY-RUN"* ]]
}

@test "desktop-base: --help shows usage" {
    prepare_runnable_script "$WORKSTATION_DIR/05-desktop-base.sh"

    run bash "$RUNNABLE_SCRIPT" --help

    [ "$status" -eq 0 ]
    [[ "$output" == *"Usage"* ]]
}

# ── shebang and standards ───────────────────────────────────────────────────

@test "desktop-base: uses #!/usr/bin/env bash" {
    run head -1 "$WORKSTATION_DIR/05-desktop-base.sh"
    [[ "$output" == "#!/usr/bin/env bash" ]]
}

@test "desktop-base: no emoji in output" {
    count=$(perl -CSD -ne '$n++ if /[\x{1F300}-\x{1F9FF}]/; END { print $n // 0 }' "$WORKSTATION_DIR/05-desktop-base.sh")
    [ "$count" = "0" ]
}
