#!/usr/bin/env bats

load test_helper

setup() {
    common_setup
    prepare_runnable_script "scripts/99-verify-install.sh"
}

@test "verify install: reports success when everything is optimal" {
    # Mock pacman to report packages present
    mock_command pacman 0 "pkg"
    # Mock systemctl to report active
    mock_command systemctl 0 "active"
    # Mock grep for kernel params and deep sleep
    mock_command grep 0 "found"
    # Mock findmnt for vault
    mock_command findmnt 0 "${TEST_HOME}/Code"
    
    # Create required files in redirected paths
    touch "${TEST_TEMP}/etc/mbpfan.conf"
    touch "${TEST_TEMP}/etc/sysctl.d/99-macbook-air-2020.conf"
    touch "${TEST_TEMP}/etc/tlp.d/10-macbook-air-2020.conf"
    mkdir -p "${TEST_TEMP}/lib/firmware/brcm"
    touch "${TEST_TEMP}/lib/firmware/brcm/brcmfmac4377b3-pcie.apple,fiji.bin"
    touch "${TEST_TEMP}/lib/firmware/brcm/brcmbt4377b3-apple,formosa.bin"
    touch "${TEST_HOME}/.vault.img"
    
    run bash "$RUNNABLE_SCRIPT"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Core Packages"* ]]
}

@test "verify install: detects missing packages" {
    mock_command pacman 1
    mock_command systemctl 0 "inactive"
    mock_command grep 1
    mock_command findmnt 1
    
    run bash "$RUNNABLE_SCRIPT"
    [[ "$output" == *"missing"* ]]
}

@test "verify install: detects reboot required for kernel" {
    mock_command pacman 0 "pkg"
    mock_command systemctl 0 "active"
    
    # The script uses eval \"\$KERNEL_ACTIVE\" where KERNEL_ACTIVE=\"grep ... /proc/cmdline\"
    # And KERNEL_SET=\"grep ... /etc/kernel/cmdline\"
    # Redirected paths:
    # /proc/cmdline -> ${TEST_TEMP}/proc/cmdline
    # /etc/kernel/cmdline -> ${TEST_TEMP}/etc/kernel/cmdline
    
    # Mock grep to return 1 for proc (ACTIVE) and 0 for etc (SET)
    mock_command_conditional grep "${TEST_TEMP}/proc/cmdline" 1 0
    
    run bash "$RUNNABLE_SCRIPT"
    [[ "$output" == *"Reboot required"* ]]
}
