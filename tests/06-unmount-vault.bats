#!/usr/bin/env bats
# Tests for scripts/06-unmount-vault.sh

load test_helper

setup() {
    common_setup
    prepare_runnable_script "$SCRIPTS_DIR/06-unmount-vault.sh"

    # Default mocks
    mock_command findmnt 0    # Default: vault IS mounted
    mock_command umount 0
    mock_command cryptsetup 0
}

teardown() {
    common_teardown
}

# ── Full unmount flow ────────────────────────────────────────────────────────

@test "unmount vault: unmounts and closes container" {
    touch "${TEST_TEMP}/dev_mapper/code_vault"

    run bash "$RUNNABLE_SCRIPT"

    [ "$status" -eq 0 ]
    [[ "$output" == *"locked and secured"* ]]
    assert_mock_called_with sudo "umount"
    assert_mock_called_with sudo "cryptsetup close"
}

# ── Not mounted but container open ───────────────────────────────────────────

@test "unmount vault: skips umount if not mounted, still closes" {
    mock_command findmnt 1    # not mounted
    touch "${TEST_TEMP}/dev_mapper/code_vault"

    run bash "$RUNNABLE_SCRIPT"

    [ "$status" -eq 0 ]
    [[ "$output" == *"not currently mounted"* ]]
    [[ "$output" == *"locked and secured"* ]]
    assert_mock_not_called umount
    assert_mock_called_with sudo "cryptsetup close"
}

# ── Not mounted, container already closed ────────────────────────────────────

@test "unmount vault: reports already locked if nothing to do" {
    mock_command findmnt 1    # not mounted
    # Don't create dev_mapper/code_vault

    run bash "$RUNNABLE_SCRIPT"

    [ "$status" -eq 0 ]
    [[ "$output" == *"not currently mounted"* ]]
    [[ "$output" == *"already locked"* ]]
    assert_mock_not_called umount
    assert_mock_not_called cryptsetup
}

# ── Unmount failure (busy device) ────────────────────────────────────────────

@test "unmount vault: errors if umount fails" {
    mock_command umount 1
    touch "${TEST_TEMP}/dev_mapper/code_vault"

    run bash "$RUNNABLE_SCRIPT"

    [ "$status" -eq 1 ]
    [[ "$output" == *"Failed to unmount"* ]]
}

# ── Uses findmnt ─────────────────────────────────────────────────────────────

@test "unmount vault: uses findmnt for mount detection" {
    mock_command findmnt 1

    run bash "$RUNNABLE_SCRIPT"

    assert_mock_called findmnt
    run grep -c "mount | grep" "$SCRIPTS_DIR/06-unmount-vault.sh"
    [ "$output" = "0" ]
}

# ── Uses env bash shebang ────────────────────────────────────────────────────

@test "unmount vault: uses #!/usr/bin/env bash shebang" {
    run head -1 "$SCRIPTS_DIR/06-unmount-vault.sh"
    [[ "$output" == "#!/usr/bin/env bash" ]]
}

# ── No emoji in output ───────────────────────────────────────────────────────

@test "unmount vault: no emoji in output" {
    count=$(perl -CSD -ne '$n++ if /[\x{1F300}-\x{1F9FF}]/; END { print $n // 0 }' "$SCRIPTS_DIR/06-unmount-vault.sh")
    [ "$count" = "0" ]
}
