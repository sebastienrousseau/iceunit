#!/usr/bin/env bats
# Tests for scripts/05-mount-vault.sh

load test_helper

setup() {
    common_setup
    prepare_runnable_script "$SCRIPTS_DIR/05-mount-vault.sh"

    # Default mocks — vault not mounted, commands succeed
    mock_command findmnt 1
    mock_command cryptsetup 0
    mock_command mount 0
    mock_command chown 0
    mock_command mkdir 0
}

teardown() {
    common_teardown
}

# ── Already mounted ──────────────────────────────────────────────────────────

@test "mount vault: exits cleanly if already mounted" {
    mock_command findmnt 0 "$TEST_HOME/Code"

    run bash "$RUNNABLE_SCRIPT"

    [ "$status" -eq 0 ]
    [[ "$output" == *"already mounted"* ]]
    assert_mock_not_called cryptsetup
    assert_mock_not_called mount
}

# ── Image not found ──────────────────────────────────────────────────────────

@test "mount vault: errors if vault image does not exist" {
    run bash "$RUNNABLE_SCRIPT"

    [ "$status" -eq 1 ]
    [[ "$output" == *"not found"* ]]
    assert_mock_not_called cryptsetup
}

# ── Full mount flow ──────────────────────────────────────────────────────────

@test "mount vault: opens container, mounts, and sets ownership" {
    touch "$TEST_HOME/.vault.img"

    # Don't pass --yes to test the prompt flow (mocked)
    run bash "$RUNNABLE_SCRIPT"

    [ "$status" -eq 0 ]
    [[ "$output" == *"mounted"* ]]
    assert_mock_called cryptsetup
    assert_mock_called_with sudo "cryptsetup open"
    assert_mock_called_with sudo "mount"
    assert_mock_called_with sudo "chown"
}

# ── Container already open ───────────────────────────────────────────────────

@test "mount vault: skips cryptsetup if container already open" {
    touch "$TEST_HOME/.vault.img"
    # Note: prepare_runnable_script replaces /dev/mapper with TEST_TEMP/dev_mapper
    mkdir -p "${TEST_TEMP}/dev_mapper"
    touch "${TEST_TEMP}/dev_mapper/code_vault"

    run bash "$RUNNABLE_SCRIPT"

    [ "$status" -eq 0 ]
    assert_mock_not_called cryptsetup
    assert_mock_called_with sudo "mount"
}

# ── Non-interactive skip ─────────────────────────────────────────────────────

@test "mount vault: skips in non-interactive mode with --yes" {
    touch "$TEST_HOME/.vault.img"
    
    # Pass --yes and ensure stdin is NOT a TTY by piping
    run bash -c "echo '' | bash $RUNNABLE_SCRIPT --yes"
    
    [ "$status" -eq 0 ]
    [[ "$output" == *"Non-interactive mode"* ]]
    assert_mock_not_called cryptsetup
}

# ── Uses findmnt (not mount|grep) ───────────────────────────────────────────

@test "mount vault: uses findmnt for mount detection" {
    mock_command findmnt 0

    run bash "$RUNNABLE_SCRIPT"

    assert_mock_called findmnt
}

# ── Uses env bash shebang ────────────────────────────────────────────────────

@test "mount vault: uses #!/usr/bin/env bash shebang" {
    assert_shebang "$SCRIPTS_DIR/05-mount-vault.sh"
}

@test "mount vault: no emoji in output" {
    assert_no_emoji "$SCRIPTS_DIR/05-mount-vault.sh"
}

# ── Non-recursive chown ─────────────────────────────────────────────────────

@test "mount vault: uses chown without -R flag" {
    run grep -c "chown -R" "$SCRIPTS_DIR/05-mount-vault.sh"
    [ "$output" = "0" ]
}
