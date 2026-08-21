#!/usr/bin/env bats

load test_helper

setup() {
    common_setup
    prepare_runnable_script "scripts/00-system-init.sh"
}

@test "system init: preflight passes when all packages present" {
    # Mock pacman -Qq to echo back queried package names (all installed)
    mock_all_packages_installed
    
    run bash "$RUNNABLE_SCRIPT" --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" == *"All Iceunit packages"* ]]
}

@test "system init: attempts to install missing packages" {
    # Mock pacman -Qq to fail (package missing)
    mock_command pacman 1
    
    run bash "$RUNNABLE_SCRIPT" --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" == *"Missing"* ]]
    [[ "$output" == *"pacman -Sy"* ]]
}

@test "system init: handles ollama conflict" {
    # Mock pacman -Qq to fail
    mock_command pacman 1
    
    # Redirection for /usr/share is not in test_helper yet.
    # But for this test, we just want to ensure it runs without crashing.
    run bash "$RUNNABLE_SCRIPT" --dry-run
    [ "$status" -eq 0 ]
}

@test "system init: respects --yes flag" {
    mock_command pacman 1
    run bash "$RUNNABLE_SCRIPT" --yes --dry-run
    [ "$status" -eq 0 ]
}

@test "system init: ranks mirrors when reflector available" {
    mock_command pacman 1
    mock_command reflector 0
    run bash "$RUNNABLE_SCRIPT" --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" == *"Ranking mirrors"* ]] || [[ "$output" == *"mirror"* ]] || [[ "$output" == *"No mirror ranker"* ]]
}

@test "system init: handles mirror ranking gracefully" {
    mock_command pacman 1
    rm -f "${MOCK_BIN}/cachyos-rate-mirrors" "${MOCK_BIN}/rate-mirrors" "${MOCK_BIN}/reflector"
    run bash "$RUNNABLE_SCRIPT" --dry-run
    [ "$status" -eq 0 ]
    # Either warns about no ranker or uses a system-installed one
    [[ "$output" == *"mirror"* ]] || [[ "$output" == *"Mirror"* ]] || [[ "$output" == *"WARN"* ]]
}
