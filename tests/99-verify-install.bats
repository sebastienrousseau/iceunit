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

@test "verify install: --help shows auto-fix flag" {
    run bash "$RUNNABLE_SCRIPT" --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"auto-fix"* ]]
}

@test "verify install: checks i915 GUC/HUC config" {
    mock_command pacman 0 "pkg"
    mock_command systemctl 0 "active"
    mock_command lsmod 0 "apple_bce"
    mock_command ip 0 "wlan0"
    mock_command findmnt 0 "Code"
    mock_command git 0 "true"
    mock_command grep 0 "match"
    mock_command timedatectl 0 "no"

    mkdir -p "${TEST_TEMP}/etc/modprobe.d"
    touch "${TEST_TEMP}/etc/modprobe.d/i915.conf"
    touch "${TEST_TEMP}/etc/mbpfan.conf"
    touch "${TEST_TEMP}/etc/sysctl.d/99-macbook-air-2020.conf"
    touch "${TEST_TEMP}/etc/tlp.d/10-macbook-air-2020.conf"
    touch "${TEST_TEMP}/lib/firmware/brcm/brcmfmac4377b3-pcie.apple,fiji.bin"
    touch "${TEST_TEMP}/lib/firmware/brcm/brcmbt4377b3-apple,formosa.bin"
    touch "${TEST_HOME}/.vault.img"

    run bash "$RUNNABLE_SCRIPT"
    [ "$status" -eq 0 ]
    [[ "$output" == *"GPU Offload"* ]]
}

@test "verify install: check function marks passing checks" {
    run bash -c '
        CHECK="\033[0;32m✓\033[0m"
        CROSS="\033[0;31m✗\033[0m"
        PENDING="\033[1;35m>\033[0m"
        LABEL="\033[1m"
        DIM="\033[38;5;241m"
        YELLOW="\033[1;33m"
        PURPLE="\033[1;35m"
        RESET="\033[0m"
        check() {
            local category="$1" software="$2" cmd="$3" status_msg="${4:-}"
            if eval "$cmd" >/dev/null 2>&1; then
                printf "  %b %b %b\n" "$CHECK" "${LABEL}${category}${RESET}" "${DIM}(${software})${RESET}"
                return 0
            else
                if [[ "$status_msg" == *"Reboot"* ]] || [[ "$status_msg" == *"pending"* ]]; then
                    printf "  %b %b%s (%s) %s%b\n" "$PENDING" "$PURPLE" "$category" "$software" "$status_msg" "$RESET"
                else
                    printf "  %b %b %b %b\n" "$CROSS" "${LABEL}${category}${RESET}" "${DIM}(${software})${RESET}" "${YELLOW}${status_msg}${RESET}"
                fi
                return 1
            fi
        }
        check "Test Category" "test-software" "true"
    '

    [ "$status" -eq 0 ]
    [[ "$output" == *"Test Category"* ]]
}

@test "verify install: check function marks failing checks" {
    run bash -c '
        CHECK="\033[0;32m✓\033[0m"
        CROSS="\033[0;31m✗\033[0m"
        PENDING="\033[1;35m>\033[0m"
        LABEL="\033[1m"
        DIM="\033[38;5;241m"
        YELLOW="\033[1;33m"
        PURPLE="\033[1;35m"
        RESET="\033[0m"
        check() {
            local category="$1" software="$2" cmd="$3" status_msg="${4:-}"
            if eval "$cmd" >/dev/null 2>&1; then
                printf "  %b %b %b\n" "$CHECK" "${LABEL}${category}${RESET}" "${DIM}(${software})${RESET}"
                return 0
            else
                if [[ "$status_msg" == *"Reboot"* ]] || [[ "$status_msg" == *"pending"* ]]; then
                    printf "  %b %b%s (%s) %s%b\n" "$PENDING" "$PURPLE" "$category" "$software" "$status_msg" "$RESET"
                else
                    printf "  %b %b %b %b\n" "$CROSS" "${LABEL}${category}${RESET}" "${DIM}(${software})${RESET}" "${YELLOW}${status_msg}${RESET}"
                fi
                return 1
            fi
        }
        check "Broken Thing" "broken-pkg" "false" "Fix required"
    '

    [ "$status" -eq 1 ]
    [[ "$output" == *"Broken Thing"* ]]
}

@test "verify install: check shows pending for reboot items" {
    run bash -c '
        CHECK="\033[0;32m✓\033[0m"
        CROSS="\033[0;31m✗\033[0m"
        PENDING="\033[1;35m>\033[0m"
        LABEL="\033[1m"
        DIM="\033[38;5;241m"
        YELLOW="\033[1;33m"
        PURPLE="\033[1;35m"
        RESET="\033[0m"
        check() {
            local category="$1" software="$2" cmd="$3" status_msg="${4:-}"
            if eval "$cmd" >/dev/null 2>&1; then
                printf "  %b %b %b\n" "$CHECK" "${LABEL}${category}${RESET}" "${DIM}(${software})${RESET}"
                return 0
            else
                if [[ "$status_msg" == *"Reboot"* ]] || [[ "$status_msg" == *"pending"* ]]; then
                    printf "  %b %b%s (%s) %s%b\n" "$PENDING" "$PURPLE" "$category" "$software" "$status_msg" "$RESET"
                else
                    printf "  %b %b %b %b\n" "$CROSS" "${LABEL}${category}${RESET}" "${DIM}(${software})${RESET}" "${YELLOW}${status_msg}${RESET}"
                fi
                return 1
            fi
        }
        check "Kernel Update" "kernel" "false" "Reboot required"
    '

    [[ "$output" == *"Reboot"* ]]
}

@test "verify install: header function formats section headers" {
    run bash -c "
        HEADER='\033[1;36m'
        RESET='\033[0m'
        header() { printf '\n%b%s%b\n' \"\$HEADER\" \"\$1\" \"\$RESET\"; }
        header 'Test Section'
    "

    [ "$status" -eq 0 ]
    [[ "$output" == *"Test Section"* ]]
}

@test "verify install: auto_fix_mark tracks fix categories" {
    run bash -c '
        declare -A FIX_SCRIPTS
        FIX_SCRIPTS=([thermal]="echo fix" [optimise]="echo fix")
        FIX_NEEDED=()
        auto_fix_mark() {
            local category="$1"
            if [[ -n "${FIX_SCRIPTS[$category]:-}" ]]; then
                local already=false
                for f in "${FIX_NEEDED[@]}"; do
                    [[ "$f" == "$category" ]] && already=true
                done
                $already || FIX_NEEDED+=("$category")
            fi
        }
        auto_fix_mark "thermal"
        auto_fix_mark "optimise"
        auto_fix_mark "thermal"
        echo "count=${#FIX_NEEDED[@]}"
        echo "first=${FIX_NEEDED[0]}"
    '

    [ "$status" -eq 0 ]
    [[ "$output" == *"count=2"* ]]
    [[ "$output" == *"first=thermal"* ]]
}

@test "verify install: detects container runtime" {
    mock_command pacman 0 "pkg"
    mock_command systemctl 0 "active"
    mock_command lsmod 0 "apple_bce"
    mock_command ip 0 "wlan0"
    mock_command findmnt 0 "Code"
    mock_command git 0 "true"
    mock_command grep 0 "match"
    mock_command docker 0

    run bash "$RUNNABLE_SCRIPT"

    [ "$status" -eq 0 ]
    [[ "$output" == *"Container"* ]]
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
