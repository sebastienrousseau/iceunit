#!/usr/bin/env bats

load test_helper

setup() {
    common_setup
    prepare_runnable_script "workstation/30-security-tools.sh"
    mock_command pacman 0
    mock_command systemctl 0
    mock_command ufw 0
}

teardown() { common_teardown; }

@test "security: runs in dry-run mode without error" {
    assert_dry_run_succeeds
}

@test "security: installs security packages via pacman" {
    run bash "$RUNNABLE_SCRIPT" --dry-run
    then_status_ok
    then_output_contains "pacman"
    then_output_contains "gitleaks"
}

@test "security: enables ufw firewall" {
    run bash "$RUNNABLE_SCRIPT" --dry-run
    then_status_ok
    then_output_contains "ufw"
}

@test "security: sets default deny incoming" {
    run bash "$RUNNABLE_SCRIPT" --dry-run
    then_status_ok
    then_output_contains "deny incoming"
}

@test "security: sets default allow outgoing" {
    run bash "$RUNNABLE_SCRIPT" --dry-run
    then_status_ok
    then_output_contains "allow outgoing"
}
