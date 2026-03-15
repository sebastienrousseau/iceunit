#!/usr/bin/env bats

load test_helper

setup() {
    common_setup
    prepare_runnable_script "workstation/20-devops-tools.sh"
    mock_command pacman 0
    mock_command tee 0
}

teardown() { common_teardown; }

@test "devops: runs in dry-run mode without error" {
    run bash "$RUNNABLE_SCRIPT" --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" == *"DRY-RUN"* ]]
}

@test "devops: installs packages via pacman" {
    run bash "$RUNNABLE_SCRIPT" --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" == *"pacman"* ]]
}

@test "devops: installs kubectl" {
    run bash "$RUNNABLE_SCRIPT" --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" == *"kubectl"* ]]
}

@test "devops: installs helm and terraform" {
    run bash "$RUNNABLE_SCRIPT" --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" == *"helm"* ]]
    [[ "$output" == *"terraform"* ]]
}

@test "devops: succeeds when kubectl is available" {
    mock_command kubectl 0
    mkdir -p "${TEST_TEMP}/etc/bash_completion.d"
    run bash "$RUNNABLE_SCRIPT" --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" == *"DevOps tooling installed"* ]]
}
