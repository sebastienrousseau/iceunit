#!/usr/bin/env bats

load test_helper

setup() {
    common_setup
    prepare_runnable_script "scripts/07-install-apps.sh"
    # Mock pacman to exist
    mock_command pacman 0
}

@test "install apps: skips when all apps present" {
    # Mock pacman -Qq to return success (0)
    mock_command pacman 0
    
    run bash "$RUNNABLE_SCRIPT" --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" == *"already installed"* ]]
}

@test "install apps: attempts to install missing apps via pacman" {
    # Mock pacman -Qq to fail (1) and pacman -S to succeed (0)
    mock_command_conditional pacman "-Qq" 1 0
    
    run bash "$RUNNABLE_SCRIPT" --dry-run
    echo "DEBUG OUTPUT: $output" >&2
    [ "$status" -eq 0 ]
    [[ "$output" == *"Missing"* ]]
    # Should contain either pacman -S or paru -S depending on system
    [[ "$output" == *" -S"* ]]
}

@test "install apps: uses paru if available" {
    mock_command_conditional pacman "-Qq" 1 0
    mock_command paru 0
    
    run bash "$RUNNABLE_SCRIPT" --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" == *"paru -S"* ]]
}

@test "install apps: respects --yes flag" {
    mock_command pacman 1
    run bash "$RUNNABLE_SCRIPT" --yes --dry-run
    [ "$status" -eq 0 ]
}
