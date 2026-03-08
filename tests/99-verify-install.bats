#!/usr/bin/env bats

load test_helper

setup() {
    common_setup
    prepare_runnable_script "scripts/99-verify-install.sh"
}

@test "verify install: reports success when everything is optimal" {
    # Mock everything to succeed
    mock_command pacman 0 "pkg"
    mock_command systemctl 0 "active"
    mock_command grep 0 "match"
    mock_command findmnt 0 "target"
    mock_command lsmod 0 "apple_bce"
    mock_command ip 0 "wlan0"
    mock_command git 0 "true"
    
    # Mock files
    mkdir -p "${TEST_TEMP}/etc/sysctl.d"
    mkdir -p "${TEST_TEMP}/etc/tlp.d"
    mkdir -p "${TEST_TEMP}/lib/firmware/brcm"
    touch "${TEST_TEMP}/etc/mbpfan.conf"
    touch "${TEST_TEMP}/etc/sysctl.d/99-macbook-air-2020.conf"
    touch "${TEST_TEMP}/etc/tlp.d/10-macbook-air-2020.conf"
    touch "${TEST_TEMP}/lib/firmware/brcm/brcmfmac4377b3-pcie.apple,fiji.bin"
    touch "${TEST_TEMP}/lib/firmware/brcm/brcmbt4377b3-apple,formosa.bin"
    
    # Ensure vault image exists in ALL possible locations the script checks
    touch "${TEST_HOME}/.vault.img"
    touch "${TEST_HOME}/Code.img"
    touch "/root/.vault.img" 2>/dev/null || true
    
    run bash "$RUNNABLE_SCRIPT"
    [ "$status" -eq 0 ]
}

@test "verify install: detects missing packages" {
    mock_command pacman 1
    run bash "$RUNNABLE_SCRIPT"
    [[ "$output" == *"missing"* ]]
}

@test "verify install: detects reboot required for kernel" {
    mock_command pacman 0 "pkg"
    mock_command systemctl 0 "active"
    mock_command lsmod 0 "apple_bce"
    mock_command ip 0 "wlan0"
    mock_command findmnt 0 "Code"
    mock_command git 0 "true"
    
    # Mock grep: fail for /proc/cmdline (Active), succeed for /etc/kernel/cmdline (Set)
    mock_command_conditional grep "${TEST_TEMP}/proc/cmdline" 1 0
    
    run bash "$RUNNABLE_SCRIPT"
    [[ "$output" == *"Reboot required"* ]]
}
