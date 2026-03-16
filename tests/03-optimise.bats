#!/usr/bin/env bats
# Tests for scripts/03-optimise.sh

load test_helper

setup() {
    common_setup
    source_script "$SCRIPTS_DIR/03-optimise.sh"

    # Reset tracking arrays
    APPLIED=()
    SKIPPED=()

    # Only mock hardware/root/package commands
    mock_command sysctl 0
    mock_command systemctl 0
    mock_command pacman 0
    mock_command mount 0
    mock_command btrfs 0
    mock_command zramctl 0 "zram0 lzo-rle 15.4G 4K 65B 12K 8 [SWAP]"
    mock_command free 0 "Swap: 15Gi 0B 15Gi"
    mock_command powerprofilesctl 0 "balanced"
    mock_command sleep 0
    mock_command findmnt 0 "test-auto-uuid"
    mock_command timedatectl 0 "no"

    # Create kernel cmdline fixture
    echo "quiet nowatchdog splash rw" > "${TEST_TEMP}/etc/kernel/cmdline"
}

teardown() {
    common_teardown
}

# ── optimise_kernel_params ───────────────────────────────────────────────────

@test "kernel params: adds missing params to cmdline" {
    echo "quiet nowatchdog splash rw" > "${TEST_TEMP}/etc/kernel/cmdline"

    run optimise_kernel_params

    [ "$status" -eq 0 ]
    [[ "$output" == *"Kernel cmdline updated"* ]]
}

@test "kernel params: skips already-present params" {
    echo "quiet nowatchdog splash rw intel_idle.max_cstate=4 snd_hda_intel.power_save=0 pcie_aspm=off mem_sleep_default=deep" > "${TEST_TEMP}/etc/kernel/cmdline"

    run optimise_kernel_params

    [ "$status" -eq 0 ]
    [[ "$output" == *"already present"* ]]
}

@test "kernel params: handles missing cmdline file" {
    rm -f "${TEST_TEMP}/etc/kernel/cmdline"

    run optimise_kernel_params

    [ "$status" -eq 0 ]
}

@test "kernel params: writes sysctl config" {
    run optimise_kernel_params

    [ -f "${TEST_TEMP}/etc/sysctl.d/99-macbook-air-2020.conf" ]
    grep -q "vm.swappiness = 10" "${TEST_TEMP}/etc/sysctl.d/99-macbook-air-2020.conf"
    grep -q "vm.vfs_cache_pressure = 50" "${TEST_TEMP}/etc/sysctl.d/99-macbook-air-2020.conf"
    grep -q "kernel.nmi_watchdog = 0" "${TEST_TEMP}/etc/sysctl.d/99-macbook-air-2020.conf"
}

@test "kernel params: sysctl config includes tcp_fastopen" {
    run optimise_kernel_params

    grep -q "net.ipv4.tcp_fastopen = 3" "${TEST_TEMP}/etc/sysctl.d/99-macbook-air-2020.conf"
}

# ── optimise_tlp ─────────────────────────────────────────────────────────────

@test "tlp: writes drop-in config when TLP installed" {
    run optimise_tlp

    [ "$status" -eq 0 ]
    [ -f "${TEST_TEMP}/etc/tlp.d/10-macbook-air-2020.conf" ]
    [[ "$output" == *"TLP service enabled"* ]]
}

@test "tlp: config has USB_AUTOSUSPEND=0" {
    run optimise_tlp

    grep -q "USB_AUTOSUSPEND=0" "${TEST_TEMP}/etc/tlp.d/10-macbook-air-2020.conf"
}

@test "tlp: config disables Wi-Fi power management" {
    run optimise_tlp

    grep -q "WIFI_PWR_ON_AC=off" "${TEST_TEMP}/etc/tlp.d/10-macbook-air-2020.conf"
    grep -q "WIFI_PWR_ON_BAT=off" "${TEST_TEMP}/etc/tlp.d/10-macbook-air-2020.conf"
}

@test "tlp: skips when TLP not installed" {
    mock_command pacman 1

    run optimise_tlp

    [ "$status" -eq 0 ]
    [[ "$output" == *"TLP not installed"* ]]
}

@test "tlp: config uses correct filename" {
    run optimise_tlp

    [ -f "${TEST_TEMP}/etc/tlp.d/10-macbook-air-2020.conf" ]
    # Not 50-macbook-air.conf
    [ ! -f "${TEST_TEMP}/etc/tlp.d/50-macbook-air.conf" ]
}

# ── optimise_btrfs ───────────────────────────────────────────────────────────

@test "btrfs: skips when noatime already in fstab" {
    echo "UUID=x / btrfs rw,noatime,compress=zstd:1 0 0" > "${TEST_TEMP}/etc/fstab"

    run optimise_btrfs

    [ "$status" -eq 0 ]
    [[ "$output" == *"noatime already"* ]]
}

@test "btrfs: shows recommendations when noatime missing" {
    echo "UUID=x / btrfs rw 0 0" > "${TEST_TEMP}/etc/fstab"

    run optimise_btrfs

    [ "$status" -eq 0 ]
    [[ "$output" == *"noatime"* ]]
    [[ "$output" == *"compress=zstd:1"* ]]
}

@test "btrfs: uses auto-detected UUID" {
    echo "UUID=x / btrfs rw 0 0" > "${TEST_TEMP}/etc/fstab"

    run optimise_btrfs

    [ "$status" -eq 0 ]
    [[ "$output" == *"test-auto-uuid"* ]]
}

# ── optimise_audio ───────────────────────────────────────────────────────────

@test "audio: writes PipeWire config with correct filename" {
    run optimise_audio

    [ "$status" -eq 0 ]
    [ -f "$HOME/.config/pipewire/pipewire.conf.d/10-t2-macbook-audio.conf" ]
}

@test "audio: config uses min-quantum 256" {
    run optimise_audio

    grep -q "min-quantum   = 256" "$HOME/.config/pipewire/pipewire.conf.d/10-t2-macbook-audio.conf"
}

@test "audio: config uses quantum 1024" {
    run optimise_audio

    grep -q "quantum       = 1024" "$HOME/.config/pipewire/pipewire.conf.d/10-t2-macbook-audio.conf"
}

@test "audio: config uses 48kHz sample rate" {
    run optimise_audio

    grep -q "rate          = 48000" "$HOME/.config/pipewire/pipewire.conf.d/10-t2-macbook-audio.conf"
}

@test "audio: skips if config already exists" {
    mkdir -p "$HOME/.config/pipewire/pipewire.conf.d"
    touch "$HOME/.config/pipewire/pipewire.conf.d/10-t2-macbook-audio.conf"

    run optimise_audio

    [ "$status" -eq 0 ]
    [[ "$output" == *"already exists"* ]]
}

# ── optimise_sleep ───────────────────────────────────────────────────────────

@test "sleep: confirms deep sleep when already default" {
    echo "s2idle [deep]" > "${TEST_TEMP}/sys/power/mem_sleep"
    mock_command echo 0

    run optimise_sleep

    [ "$status" -eq 0 ]
    [[ "$output" == *"deep"* ]] || [[ "$output" == *"Deep"* ]]
}

@test "sleep: installs suspend fix service" {
    echo "s2idle [deep]" > "${TEST_TEMP}/sys/power/mem_sleep"

    run optimise_sleep

    [ -f "${TEST_TEMP}/etc/systemd/system/macbook-suspend-fix.service" ]
}

@test "sleep: suspend service reloads only apple-bce" {
    echo "s2idle [deep]" > "${TEST_TEMP}/sys/power/mem_sleep"

    run optimise_sleep

    grep -q "apple-bce" "${TEST_TEMP}/etc/systemd/system/macbook-suspend-fix.service"
    ! grep -q "brcmfmac" "${TEST_TEMP}/etc/systemd/system/macbook-suspend-fix.service"
}

# ── verify_zram ──────────────────────────────────────────────────────────────

@test "zram: reports configured ZRAM" {
    run verify_zram

    [ "$status" -eq 0 ]
    [[ "$output" == *"correctly configured"* ]]
}

# ── check_power_profiles ────────────────────────────────────────────────────

@test "power profiles: warns about conflict when ppd active" {
    mock_command_conditional systemctl "is-active power-profiles-daemon" 0 0

    run check_power_profiles

    [ "$status" -eq 0 ]
    [[ "$output" == *"conflict"* ]] || [[ "$output" == *"Recommended"* ]]
}

# ── configure_i915 ──────────────────────────────────────────────────────────

@test "i915: writes modprobe config with GUC/HUC" {
    run configure_i915

    [ "$status" -eq 0 ]
    [ -f "${TEST_TEMP}/etc/modprobe.d/i915.conf" ]
    grep -q "enable_guc=3" "${TEST_TEMP}/etc/modprobe.d/i915.conf"
    grep -q "enable_fbc=1" "${TEST_TEMP}/etc/modprobe.d/i915.conf"
}

@test "i915: skips if config already exists" {
    mkdir -p "${TEST_TEMP}/etc/modprobe.d"
    echo "options i915 enable_guc=3" > "${TEST_TEMP}/etc/modprobe.d/i915.conf"

    run configure_i915

    [ "$status" -eq 0 ]
    [[ "$output" == *"already exists"* ]]
}

# ── configure_rtc ──────────────────────────────────────────────────────────

@test "rtc: sets UTC for macOS dual-boot" {
    mock_command timedatectl 0 "yes"

    run configure_rtc

    [ "$status" -eq 0 ]
    assert_mock_called "timedatectl"
    [[ "$output" == *"UTC"* ]]
}

@test "rtc: skips when already set to UTC" {
    mock_command timedatectl 0 "no"

    run configure_rtc

    [ "$status" -eq 0 ]
    [[ "$output" == *"already set to UTC"* ]]
}

# ── install_recommended_packages ─────────────────────────────────────────────

@test "packages: skips when all installed" {
    assert_package_skip install_recommended_packages "already installed"
}

@test "packages: installs missing packages" {
    mock_command pacman 1

    run install_recommended_packages

    [ "$status" -eq 0 ]
}

# ── print_summary ────────────────────────────────────────────────────────────

@test "summary: displays applied and skipped items" {
    assert_summary_shows_items "kernel-cmdline,sysctl,tlp" "zram,btrfs-fstab"
}

# ── main execution model ────────────────────────────────────────────────────

@test "main: runs audio-only when flag set" {
    run bash -c "
        export PATH='${PATH}' HOME='${HOME}' TEST_TEMP='${TEST_TEMP}'
        source '${SOURCEABLE_SCRIPT}'
        APPLIED=(); SKIPPED=()
        main --audio-only
    "

    [ "$status" -eq 0 ]
}

@test "main: warns about root when not root" {
    run bash -c "
        export PATH='${PATH}' HOME='${HOME}' TEST_TEMP='${TEST_TEMP}'
        source '${SOURCEABLE_SCRIPT}'
        APPLIED=(); SKIPPED=()
        main
    "

    [[ "$output" == *"root"* ]] || [[ "$output" == *"sudo"* ]]
}

# ── script quality checks ───────────────────────────────────────────────────

@test "optimise: no hardcoded UUIDs" {
    run grep -c "e22d4eac" "$SCRIPTS_DIR/03-optimise.sh"
    [ "$output" = "0" ]
}

@test "optimise: uses findmnt for UUID detection" {
    run grep -c "findmnt -rno UUID" "$SCRIPTS_DIR/03-optimise.sh"
    [ "$output" != "0" ]
}

@test "optimise: uses #!/usr/bin/env bash" {
    assert_shebang "$SCRIPTS_DIR/03-optimise.sh"
}

@test "optimise: no emoji in output" {
    assert_no_emoji "$SCRIPTS_DIR/03-optimise.sh"
}
