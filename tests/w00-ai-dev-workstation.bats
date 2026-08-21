#!/usr/bin/env bats

load test_helper

setup() {
    common_setup
    prepare_runnable_script "workstation/00-ai-dev-workstation.sh"
    mock_command pacman 0
    mock_command pipx 0
    mock_command npm 0
    mock_command systemctl 0
    mock_command usermod 0
}

teardown() { common_teardown; }

@test "ai-dev: runs in dry-run mode without error" {
    assert_dry_run_succeeds
}

@test "ai-dev: installs main packages via pacman" {
    run bash "$RUNNABLE_SCRIPT" --dry-run
    then_status_ok
    then_output_contains "pacman"
}

@test "ai-dev: installs python tools via pipx" {
    run bash "$RUNNABLE_SCRIPT" --dry-run
    then_status_ok
    then_output_contains "pipx"
}

@test "ai-dev: installs node tools via npm" {
    run bash "$RUNNABLE_SCRIPT" --dry-run
    then_status_ok
    then_output_contains "npm"
}

@test "ai-dev: enables docker when available" {
    mock_command docker 0
    run bash "$RUNNABLE_SCRIPT" --dry-run
    then_status_ok
    then_output_contains "docker"
}

@test "ai-dev: falls back to podman when docker missing" {
    mock_command podman 0
    rm -f "${MOCK_BIN}/docker"
    run bash "$RUNNABLE_SCRIPT" --dry-run
    then_status_ok
}
