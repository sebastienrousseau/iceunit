#!/usr/bin/env bats
# Tests for scripts/00-setup-vault.sh

load test_helper

setup() {
    common_setup
    source_script "$SCRIPTS_DIR/00-setup-vault.sh"

    # Default mocks
    mock_command findmnt 1          # not mounted
    mock_command cryptsetup 0
    mock_command mkfs.btrfs 0
    mock_command mount 0
    mock_command chown 0
    mock_command fallocate 0
    mock_command chmod 0
    mock_command df 0 "Filesystem Size Used Avail Use% Mount"
}

teardown() {
    common_teardown
}

# ── preflight ────────────────────────────────────────────────────────────────

@test "preflight: passes when all requirements met" {
    run preflight
    [ "$status" -eq 0 ]
    [[ "$output" == *"All checks passed"* ]]
}

@test "preflight: errors if cryptsetup missing" {
    rm -f "${MOCK_BIN}/cryptsetup"
    export PATH="${MOCK_BIN}"
    run preflight
    [ "$status" -eq 1 ]
    [[ "$output" == *"cryptsetup not found"* ]]
}

@test "preflight: errors if mkfs.btrfs missing" {
    rm -f "${MOCK_BIN}/mkfs.btrfs"
    export PATH="${MOCK_BIN}"
    run preflight
    [ "$status" -eq 1 ]
    [[ "$output" == *"btrfs-progs not found"* ]]
}

@test "preflight: skips if vault image exists" {
    touch "$TEST_HOME/.vault.img"
    run preflight
    [ "$status" -eq 0 ]
    [[ "$output" == *"exists"* ]]
}

@test "preflight: skips if mount point already mounted" {
    mock_command findmnt 0  # mounted
    run preflight
    [ "$status" -eq 0 ]
    [[ "$output" == *"mounted"* ]]
}

@test "preflight: uses findmnt not mount|grep" {
    run preflight
    assert_mock_called findmnt
}

# ── choose_size ──────────────────────────────────────────────────────────────

@test "choose_size: accepts default size when input empty" {
    run_with_input '\ny\n' choose_size
    [ "$status" -eq 0 ]
    [[ "$output" == *"60G"* ]]
}

@test "choose_size: accepts custom valid size" {
    run_with_input '100G\ny\n' choose_size
    [ "$status" -eq 0 ]
    [[ "$output" == *"100G"* ]]
}

@test "choose_size: rejects zero size (0G)" {
    run_with_input '0G\n' choose_size
    [ "$status" -eq 1 ]
    [[ "$output" == *"Invalid size"* ]]
}

@test "choose_size: rejects invalid format" {
    run_with_input 'abc\n' choose_size
    [ "$status" -eq 1 ]
    [[ "$output" == *"Invalid size"* ]]
}

@test "choose_size: rejects 0M" {
    run_with_input '0M\n' choose_size
    [ "$status" -eq 1 ]
    [[ "$output" == *"Invalid size"* ]]
}

@test "choose_size: aborts on negative confirmation" {
    run_with_input '50G\nn\n' choose_size
    [ "$status" -eq 0 ]
    [[ "$output" == *"Aborted"* ]]
}

@test "choose_size: accepts lowercase 'g'" {
    run_with_input '50g\ny\n' choose_size
    [ "$status" -eq 0 ]
    [[ "$output" == *"50g"* ]]
}

@test "choose_size: accepts megabyte size" {
    run_with_input '512M\ny\n' choose_size
    [ "$status" -eq 0 ]
    [[ "$output" == *"512M"* ]]
}

# ── create_image ─────────────────────────────────────────────────────────────

@test "create_image: uses fallocate when available" {
    VAULT_SIZE="60G"
    VAULT_IMG="$TEST_HOME/.vault.img"
    run create_image
    [ "$status" -eq 0 ]
    [[ "$output" == *"Image created"* ]]
    assert_mock_called fallocate
}

@test "create_image: falls back to dd when fallocate fails" {
    mock_command fallocate 1
    mock_command dd 0
    mock_command numfmt 0 "62914560000"
    VAULT_SIZE="60G"
    VAULT_IMG="$TEST_HOME/.vault.img"
    run create_image
    [ "$status" -eq 0 ]
    assert_mock_called dd
}

@test "create_image: errors when both methods fail" {
    mock_command fallocate 1
    mock_command dd 1
    VAULT_SIZE="60G"
    VAULT_IMG="$TEST_HOME/.vault.img"
    run create_image
    [ "$status" -eq 1 ]
    [[ "$output" == *"Failed to create"* ]]
}

# ── format_luks ──────────────────────────────────────────────────────────────

@test "format_luks: calls cryptsetup luksFormat with correct params" {
    VAULT_IMG="$TEST_HOME/.vault.img"
    run format_luks
    [ "$status" -eq 0 ]
    [[ "$output" == *"LUKS2 encryption applied"* ]]
    assert_mock_called_with sudo "cryptsetup luksFormat"
}

# ── initialise_filesystem ────────────────────────────────────────────────────

@test "initialise_filesystem: opens, formats btrfs, mounts, chowns" {
    MAPPER_NAME="code_vault"
    MOUNT_POINT="$TEST_HOME/Code"
    VAULT_IMG="$TEST_HOME/.vault.img"
    run initialise_filesystem
    [ "$status" -eq 0 ]
    [[ "$output" == *"Vault mounted"* ]]
    assert_mock_called_with sudo "cryptsetup open"
    assert_mock_called_with sudo "mkfs.btrfs"
    assert_mock_called_with sudo "mount"
    assert_mock_called_with sudo "chown"
}

# ── verify ───────────────────────────────────────────────────────────────────

@test "verify: succeeds when mounted" {
    mock_command findmnt 0
    MOUNT_POINT="$TEST_HOME/Code"
    VAULT_IMG="$TEST_HOME/.vault.img"
    run verify
    [ "$status" -eq 0 ]
    [[ "$output" == *"mounted and ready"* ]]
}

@test "verify: errors when not mounted" {
    mock_command findmnt 1
    MOUNT_POINT="$TEST_HOME/Code"
    VAULT_IMG="$TEST_HOME/.vault.img"
    run verify
    [ "$status" -eq 1 ]
    [[ "$output" == *"verification failed"* ]]
}

# ── print_next_steps ─────────────────────────────────────────────────────────

@test "print_next_steps: displays usage instructions" {
    MOUNT_POINT="$TEST_HOME/Code"
    VAULT_IMG="$TEST_HOME/.vault.img"
    run print_next_steps
    [ "$status" -eq 0 ]
    [[ "$output" == *"05-mount-vault.sh"* ]]
    [[ "$output" == *"06-unmount-vault.sh"* ]]
    [[ "$output" == *"NOT auto-mounted"* ]]
}

# ── shebang and standards ───────────────────────────────────────────────────

@test "setup vault: uses #!/usr/bin/env bash" {
    run head -1 "$SCRIPTS_DIR/00-setup-vault.sh"
    [[ "$output" == "#!/usr/bin/env bash" ]]
}

@test "setup vault: no emoji in output" {
    run grep -cP '[\x{1F300}-\x{1F9FF}]' "$SCRIPTS_DIR/00-setup-vault.sh"
    [ "$output" = "0" ]
}

@test "setup vault: no mount|grep pattern" {
    run grep -c "mount | grep" "$SCRIPTS_DIR/00-setup-vault.sh"
    [ "$output" = "0" ]
}
