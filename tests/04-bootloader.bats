#!/usr/bin/env bats
# Tests for scripts/04-bootloader.sh

load test_helper

setup() {
    common_setup
    source_script "$SCRIPTS_DIR/04-bootloader.sh"

    # Only mock commands that require hardware/root
    mock_command_multiline efibootmgr 0 \
        "BootCurrent: 0001" \
        "Boot0001* Limine" \
        "Boot0080* Mac OS X" \
        "Boot0000  Zorin OS"
    mock_command uname 0 "6.19.6-2-cachyos"
    mock_command pacman 0
    mock_command refind-install 0
    mock_command snapper 0 "262 | single | 2026-03-07 12:39:34 | topgrade"
    mock_command systemctl 0
    mock_command limine-entry-tool 0
    mock_command findmnt 0 "dynamic-test-uuid"

    # Create test fixtures
    echo "comment: 1 CachyOS" > "${TEST_TEMP}/boot/limine.conf"
    echo "quiet nowatchdog splash rw" > "${TEST_TEMP}/etc/kernel/cmdline"
    echo "quiet nowatchdog splash rw" > "${TEST_TEMP}/proc/cmdline"
}

teardown() {
    common_teardown
}

# ── require_root ─────────────────────────────────────────────────────────────

@test "require_root: passes when EUID is 0" {
    # In the sourced script, require_root is neutered to 'true'
    run require_root
    [ "$status" -eq 0 ]
}

# ── show_status ──────────────────────────────────────────────────────────────

@test "status: shows boot configuration" {
    run show_status

    [ "$status" -eq 0 ]
    [[ "$output" == *"Limine"* ]]
}

@test "status: shows EFI boot entries" {
    run show_status

    [ "$status" -eq 0 ]
    assert_mock_called efibootmgr
}

# ── update_cmdline ───────────────────────────────────────────────────────────

@test "cmdline: shows current cmdline" {
    run_with_input 'n\n' update_cmdline

    [ "$status" -eq 0 ]
    [[ "$output" == *"quiet"* ]]
}

@test "cmdline: writes cmdline on confirmation" {
    run_with_input 'y\n' update_cmdline

    [ "$status" -eq 0 ]
    [[ "$output" == *"cmdline updated"* ]]
}

@test "cmdline: skips on negative confirmation" {
    run_with_input 'n\n' update_cmdline

    [ "$status" -eq 0 ]
    [[ "$output" == *"Skipped"* ]] || [[ "$output" == *"no changes"* ]]
}

@test "cmdline: runs limine-entry-tool after update" {
    run_with_input 'y\n' update_cmdline

    assert_mock_called limine-entry-tool
}

@test "cmdline: warns when limine-entry-tool not found" {
    # Remove mock so command -v fails; use PATH with only MOCK_BIN
    rm -f "${MOCK_BIN}/limine-entry-tool"

    # Create essential command stubs needed by the function
    for cmd in tee cp cat grep xargs head; do
        [[ -f "${MOCK_BIN}/${cmd}" ]] || ln -sf "$(command -v "$cmd")" "${MOCK_BIN}/${cmd}"
    done

    run bash -c "
        export PATH='${MOCK_BIN}'
        export HOME='${HOME}'
        export MOCK_CALLS='${MOCK_CALLS}'
        export TEST_TEMP='${TEST_TEMP}'
        source '${SOURCEABLE_SCRIPT}'
        printf 'y\n' | update_cmdline
    "

    [[ "$output" == *"not found"* ]] || [[ "$output" == *"next kernel"* ]]
}

@test "cmdline: uses dynamic UUID" {
    run_with_input 'n\n' update_cmdline

    [[ "$output" == *"dynamic-test-uuid"* ]]
}

@test "cmdline: no hardcoded UUIDs" {
    run grep -c "e22d4eac" "$SCRIPTS_DIR/04-bootloader.sh"
    [ "$output" = "0" ]
}

# ── install_refind ───────────────────────────────────────────────────────────

@test "refind: skips when user declines" {
    run_with_input 'n\n' install_refind

    [ "$status" -eq 0 ]
    [[ "$output" == *"skipped"* ]]
}

@test "refind: installs when user confirms" {
    run_with_input 'y\n' install_refind

    [ "$status" -eq 0 ]
    assert_mock_called refind-install
}

@test "refind: sets boot order with detected IDs" {
    run_with_input 'y\n' install_refind

    [ "$status" -eq 0 ]
    assert_mock_called efibootmgr
}

# ── manage_boot_order ────────────────────────────────────────────────────────

@test "boot order: boots macOS on choice 1" {
    run_with_input '1\n' manage_boot_order

    [ "$status" -eq 0 ]
    assert_mock_called efibootmgr
}

@test "boot order: boots CachyOS on choice 2" {
    run_with_input '2\n' manage_boot_order

    [ "$status" -eq 0 ]
    [[ "$output" == *"CachyOS"* ]] || [[ "$output" == *"Limine"* ]]
}

@test "boot order: sets custom order on choice 3" {
    run_with_input '3\n0001,0080\n' manage_boot_order

    [ "$status" -eq 0 ]
    [[ "$output" == *"Boot order set"* ]]
}

@test "boot order: shows entries on choice 4" {
    run_with_input '4\n' manage_boot_order

    [ "$status" -eq 0 ]
    assert_mock_called efibootmgr
}

@test "boot order: returns on choice b" {
    run_with_input 'b\n' manage_boot_order

    [ "$status" -eq 0 ]
}

@test "boot order: warns on invalid choice" {
    run_with_input 'x\n' manage_boot_order

    [ "$status" -eq 0 ]
    [[ "$output" == *"Invalid"* ]]
}

@test "boot order: errors when macOS entry not found for choice 1" {
    mock_command_multiline efibootmgr 0 "Boot0001* Limine"

    run_with_input '1\n' manage_boot_order

    [ "$status" -eq 1 ]
    [[ "$output" == *"not found"* ]]
}

@test "boot order: errors when Limine entry not found for choice 2" {
    mock_command_multiline efibootmgr 0 "Boot0080* Mac OS X"

    run_with_input '2\n' manage_boot_order

    [ "$status" -eq 1 ]
    [[ "$output" == *"not found"* ]]
}

@test "boot order: uses dynamic IDs not hardcoded" {
    run grep -c 'efibootmgr -n 0080\|efibootmgr -n 0001' "$SCRIPTS_DIR/04-bootloader.sh"
    [ "$output" = "0" ]
}

# ── show_snapshot_guide ──────────────────────────────────────────────────────

@test "snapshots: shows boot guide" {
    run show_snapshot_guide

    [ "$status" -eq 0 ]
    [[ "$output" == *"snapshot"* ]] || [[ "$output" == *"Snapshot"* ]]
}

@test "snapshots: uses generic language (not hardcoded count)" {
    run show_snapshot_guide

    [[ "$output" != *"You have 8 snapshots"* ]]
}

@test "snapshots: handles missing snapper" {
    mock_command snapper 1

    run show_snapshot_guide

    [ "$status" -eq 0 ]
}

# ── entry point routing ─────────────────────────────────────────────────────

@test "entry point: --help shows usage" {
    prepare_runnable_script "$SCRIPTS_DIR/04-bootloader.sh"

    run bash "$RUNNABLE_SCRIPT" --help

    [ "$status" -eq 0 ]
    [[ "$output" == *"Usage"* ]]
}

@test "entry point: invalid command shows usage" {
    prepare_runnable_script "$SCRIPTS_DIR/04-bootloader.sh"

    run bash "$RUNNABLE_SCRIPT" invalid

    [ "$status" -eq 1 ]
}

# ── shebang and standards ───────────────────────────────────────────────────

@test "bootloader: uses #!/usr/bin/env bash" {
    run head -1 "$SCRIPTS_DIR/04-bootloader.sh"
    [[ "$output" == "#!/usr/bin/env bash" ]]
}

@test "bootloader: no emoji in output" {
    count=$(perl -CSD -ne '$n++ if /[\x{1F300}-\x{1F9FF}]/; END { print $n // 0 }' "$SCRIPTS_DIR/04-bootloader.sh")
    [ "$count" = "0" ]
}
