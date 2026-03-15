#!/usr/bin/env bats
# Tests for scripts/02-wifi-firmware.sh

load test_helper

setup() {
    common_setup
    source_script "$SCRIPTS_DIR/02-wifi-firmware.sh"

    # Only mock hardware/network commands
    mock_command ip 0 "3: wlp3s0: <BROADCAST,MULTICAST,UP>"
    mock_command rfkill 0 "0: hci0: Bluetooth"
    mock_command curl 0
    mock_command tar 0
    mock_command modprobe 0
}

teardown() {
    common_teardown
}

# ── verify_firmware ──────────────────────────────────────────────────────────

@test "verify: passes when all firmware files present" {
    local fw_dir="${TEST_TEMP}/lib/firmware/brcm"
    touch "${fw_dir}/brcmfmac4377b3-pcie.apple,fiji.bin"
    touch "${fw_dir}/brcmfmac4377b3-pcie.apple,fiji.clm_blob"
    touch "${fw_dir}/brcmfmac4377b3-pcie.apple,fiji.txcap_blob"
    touch "${fw_dir}/brcmbt4377b3-apple,formosa.bin"
    touch "${fw_dir}/brcmbt4377b3-apple,formosa.ptb"

    run verify_firmware

    [ "$status" -eq 0 ]
    [[ "$output" == *"All required firmware files present"* ]]
}

@test "verify: warns when firmware files missing" {
    run verify_firmware

    [ "$status" -eq 0 ]
    [[ "$output" == *"MISSING"* ]]
}

@test "verify: detects Wi-Fi interface" {
    local fw_dir="${TEST_TEMP}/lib/firmware/brcm"
    touch "${fw_dir}/brcmfmac4377b3-pcie.apple,fiji.bin"
    touch "${fw_dir}/brcmfmac4377b3-pcie.apple,fiji.clm_blob"
    touch "${fw_dir}/brcmfmac4377b3-pcie.apple,fiji.txcap_blob"
    touch "${fw_dir}/brcmbt4377b3-apple,formosa.bin"
    touch "${fw_dir}/brcmbt4377b3-apple,formosa.ptb"

    run verify_firmware

    [[ "$output" == *"Wi-Fi interface"* ]]
}

@test "verify: warns when Wi-Fi interface not found" {
    local fw_dir="${TEST_TEMP}/lib/firmware/brcm"
    touch "${fw_dir}/brcmfmac4377b3-pcie.apple,fiji.bin"
    touch "${fw_dir}/brcmfmac4377b3-pcie.apple,fiji.clm_blob"
    touch "${fw_dir}/brcmfmac4377b3-pcie.apple,fiji.txcap_blob"
    touch "${fw_dir}/brcmbt4377b3-apple,formosa.bin"
    touch "${fw_dir}/brcmbt4377b3-apple,formosa.ptb"

    mock_command ip 0 "1: lo: <LOOPBACK>"

    run verify_firmware

    [[ "$output" == *"No Wi-Fi interface"* ]]
}

@test "verify: detects Bluetooth interface" {
    local fw_dir="${TEST_TEMP}/lib/firmware/brcm"
    touch "${fw_dir}/brcmfmac4377b3-pcie.apple,fiji.bin"
    touch "${fw_dir}/brcmfmac4377b3-pcie.apple,fiji.clm_blob"
    touch "${fw_dir}/brcmfmac4377b3-pcie.apple,fiji.txcap_blob"
    touch "${fw_dir}/brcmbt4377b3-apple,formosa.bin"
    touch "${fw_dir}/brcmbt4377b3-apple,formosa.ptb"

    run verify_firmware

    [[ "$output" == *"Bluetooth interface present"* ]]
}

@test "verify: warns when Bluetooth not found" {
    local fw_dir="${TEST_TEMP}/lib/firmware/brcm"
    touch "${fw_dir}/brcmfmac4377b3-pcie.apple,fiji.bin"
    touch "${fw_dir}/brcmfmac4377b3-pcie.apple,fiji.clm_blob"
    touch "${fw_dir}/brcmfmac4377b3-pcie.apple,fiji.txcap_blob"
    touch "${fw_dir}/brcmbt4377b3-apple,formosa.bin"
    touch "${fw_dir}/brcmbt4377b3-apple,formosa.ptb"

    mock_command rfkill 0 ""

    run verify_firmware

    [[ "$output" == *"No Bluetooth interface"* ]]
}

# ── backup_firmware ──────────────────────────────────────────────────────────

@test "backup: creates backup directory and manifest" {
    run backup_firmware

    [ "$status" -eq 0 ]
    [ -d "$HOME/.config/firmware-backup/brcm" ]
    [ -f "$HOME/.config/firmware-backup/brcm/MANIFEST.txt" ]
}

# ── restore_firmware ─────────────────────────────────────────────────────────

@test "restore: errors when no backup exists" {
    run restore_firmware

    [ "$status" -eq 1 ]
    [[ "$output" == *"No backup found"* ]]
}

@test "restore: restores from backup" {
    mkdir -p "$HOME/.config/firmware-backup/brcm"
    touch "$HOME/.config/firmware-backup/brcm/brcmfmac4377b3-pcie.apple,fiji.bin"

    run restore_firmware

    [ "$status" -eq 0 ]
    [[ "$output" == *"Firmware restored"* ]]
}

# ── install_from_package ─────────────────────────────────────────────────────

@test "install-pkg: downloads and extracts firmware" {
    run install_from_package

    [ "$status" -eq 0 ]
    [[ "$output" == *"Firmware installed from package"* ]]
    assert_mock_called curl
    assert_mock_called tar
}

@test "install-pkg: errors on download failure" {
    mock_command curl 1

    run install_from_package

    [ "$status" -eq 1 ]
    [[ "$output" == *"Download failed"* ]]
}

# ── show_macos_extraction_guide ──────────────────────────────────────────────

@test "guide: displays extraction instructions" {
    run show_macos_extraction_guide

    [ "$status" -eq 0 ]
    [[ "$output" == *"OPTION A"* ]]
    [[ "$output" == *"OPTION B"* ]]
    [[ "$output" == *"OPTION C"* ]]
}

# ── usage ────────────────────────────────────────────────────────────────────

@test "usage: displays available commands" {
    run usage

    [ "$status" -eq 0 ]
    [[ "$output" == *"verify"* ]]
    [[ "$output" == *"backup"* ]]
    [[ "$output" == *"restore"* ]]
    [[ "$output" == *"install-pkg"* ]]
}

# ── shebang and standards ───────────────────────────────────────────────────

@test "wifi firmware: uses #!/usr/bin/env bash" {
    run head -1 "$SCRIPTS_DIR/02-wifi-firmware.sh"
    [[ "$output" == "#!/usr/bin/env bash" ]]
}

@test "wifi firmware: no emoji in output" {
    count=$(perl -CSD -ne '$n++ if /[\x{1F300}-\x{1F9FF}]/; END { print $n // 0 }' "$SCRIPTS_DIR/02-wifi-firmware.sh")
    [ "$count" = "0" ]
}
