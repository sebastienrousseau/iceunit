#!/usr/bin/env bats

load test_helper

setup() {
    common_setup
    prepare_runnable_script "workstation/10-gnome-productivity.sh"
}

teardown() { common_teardown; }

@test "gnome: exits 0 when GNOME not detected" {
    # This test is meaningful only when gsettings is absent (e.g. CI containers)
    rm -f "${MOCK_BIN}/gsettings"
    if command -v gsettings >/dev/null 2>&1; then
        skip "gsettings available on host — tested in CI containers"
    fi
    run bash "$RUNNABLE_SCRIPT"
    [ "$status" -eq 0 ]
    [[ "$output" == *"GNOME not detected"* ]]
}

@test "gnome: applies settings in dry-run mode" {
    mock_command gsettings 0
    run bash "$RUNNABLE_SCRIPT" --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" == *"DRY-RUN"* ]]
    [[ "$output" == *"gsettings"* ]]
}

@test "gnome: disables animations" {
    mock_command gsettings 0
    run bash "$RUNNABLE_SCRIPT" --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" == *"enable-animations"* ]]
}

@test "gnome: sets workspace keybindings" {
    mock_command gsettings 0
    run bash "$RUNNABLE_SCRIPT" --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" == *"switch-to-workspace"* ]]
}

@test "gnome: sets terminal shortcut" {
    mock_command gsettings 0
    run bash "$RUNNABLE_SCRIPT" --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" == *"terminal"* ]]
}
