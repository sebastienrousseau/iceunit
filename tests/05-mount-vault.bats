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
    mock_command findmnt 0 "$HOME/Code"

    run bash "$RUNNABLE_SCRIPT"

    [ "$status" -eq 0 ]
    [[ "$output" == *"already mounted"* ]]
    assert_mock_not_called cryptsetup
    assert_mock_not_called mount
}

# ── Image not found ──────────────────────────────────────────────────────────

@test "mount vault: errors if vault image does not exist" {
    # Don't create .vault.img

    run bash "$RUNNABLE_SCRIPT"

    [ "$status" -eq 1 ]
    [[ "$output" == *"not found"* ]]
    assert_mock_not_called cryptsetup
}

# ── Full mount flow ──────────────────────────────────────────────────────────

@test "mount vault: opens container, mounts, and sets ownership" {
    touch "$HOME/.vault.img"

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
    touch "$HOME/.vault.img"
    touch "${TEST_TEMP}/dev_mapper/code_vault"

    run bash "$RUNNABLE_SCRIPT"

    [ "$status" -eq 0 ]
    assert_mock_not_called cryptsetup
    assert_mock_called_with sudo "mount"
}

# ── Uses findmnt (not mount|grep) ───────────────────────────────────────────

@test "mount vault: uses findmnt for mount detection" {
    mock_command findmnt 0

    run bash "$RUNNABLE_SCRIPT"

    assert_mock_called findmnt
    # Verify no 'mount | grep' pattern by checking script source
    run grep -c "mount | grep" "$SCRIPTS_DIR/05-mount-vault.sh"
    [ "$output" = "0" ]
}

# ── Uses env bash shebang ────────────────────────────────────────────────────

@test "mount vault: uses #!/usr/bin/env bash shebang" {
    run head -1 "$SCRIPTS_DIR/05-mount-vault.sh"
    [[ "$output" == "#!/usr/bin/env bash" ]]
}

# ── No emoji in output ───────────────────────────────────────────────────────

@test "mount vault: no emoji in output" {
    run grep -cP '[\x{1F300}-\x{1F9FF}]' "$SCRIPTS_DIR/05-mount-vault.sh"
    [ "$output" = "0" ]
}

# ── Non-recursive chown ─────────────────────────────────────────────────────

@test "mount vault: uses chown without -R flag" {
    run grep -c "chown -R" "$SCRIPTS_DIR/05-mount-vault.sh"
    [ "$output" = "0" ]
}
