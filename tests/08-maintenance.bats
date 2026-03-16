#!/usr/bin/env bats
# Tests for scripts/08-maintenance.sh

load test_helper

setup() {
    common_setup
    source_script "$SCRIPTS_DIR/08-maintenance.sh"

    # Mock commands that require hardware/root/packages
    mock_command lsmod 0 "apple_bce 12345 0"
    mock_command systemctl 0
    mock_command pacman 0
    mock_command paru 0
    mock_command yay 0
    mock_command runuser 0
    mock_command fstrim 0
    mock_command paccache 0
    mock_command journalctl 0
    mock_command pgrep 0
}

teardown() {
    common_teardown
}

# ── system_upgrade ────────────────────────────────────────────────────────────

@test "system upgrade: calls paru when available" {
    mock_command paru 0

    run system_upgrade

    [ "$status" -eq 0 ]
    assert_mock_called "runuser"
    [[ "$output" == *"paru"* ]]
}

@test "system upgrade: falls back to yay when no paru" {
    rm -f "${MOCK_BIN}/paru"
    # Symlink bash so mock script shebangs (#!/usr/bin/env bash) work
    ln -sf /usr/bin/bash "${MOCK_BIN}/bash"

    run bash -c "
        export PATH='${MOCK_BIN}'
        export HOME='${HOME}'
        export MOCK_CALLS='${MOCK_CALLS}'
        export TEST_TEMP='${TEST_TEMP}'
        source '${SOURCEABLE_SCRIPT}'
        system_upgrade
    "

    [ "$status" -eq 0 ]
    assert_mock_called "runuser"
    [[ "$output" == *"yay"* ]]
}

@test "system upgrade: falls back to pacman when no AUR helper" {
    rm -f "${MOCK_BIN}/paru"
    rm -f "${MOCK_BIN}/yay"
    ln -sf /usr/bin/bash "${MOCK_BIN}/bash"

    run bash -c "
        export PATH='${MOCK_BIN}'
        export HOME='${HOME}'
        export MOCK_CALLS='${MOCK_CALLS}'
        export TEST_TEMP='${TEST_TEMP}'
        source '${SOURCEABLE_SCRIPT}'
        system_upgrade
    "

    [ "$status" -eq 0 ]
    assert_mock_called "pacman"
    [[ "$output" == *"pacman"* ]]
}

@test "system upgrade: ranks mirrors when reflector available" {
    mock_command reflector 0

    run system_upgrade

    [ "$status" -eq 0 ]
    [[ "$output" == *"mirror"* ]] || [[ "$output" == *"Mirror"* ]] || [[ "$output" == *"upgrade"* ]]
}

# ── print_summary ─────────────────────────────────────────────────────────────

@test "summary: displays applied and skipped items" {
    assert_summary_shows_items "ssd-trim,journal-vacuum" "package-cache"
}

@test "summary: shows complete message" {
    assert_summary_shows_items "t2-health"
}

# ── t2_health ────────────────────────────────────────────────────────────────

@test "t2 health: detects apple_bce loaded" {
    mock_command lsmod 0 "apple_bce 12345 0"

    run t2_health

    [ "$status" -eq 0 ]
    [[ "$output" == *"apple_bce module loaded"* ]]
}

@test "t2 health: warns when apple_bce missing" {
    mock_command lsmod 0 "snd_hda_intel 54321 0"

    run t2_health

    [ "$status" -eq 0 ]
    [[ "$output" == *"apple_bce module NOT loaded"* ]]
}

@test "t2 health: detects mbpfan active" {
    mock_command_conditional systemctl "is-active mbpfan" 0 0

    run t2_health

    [ "$status" -eq 0 ]
    [[ "$output" == *"mbpfan is active"* ]]
}

# ── ssd_trim ─────────────────────────────────────────────────────────────────

@test "ssd trim: calls fstrim" {
    run ssd_trim

    [ "$status" -eq 0 ]
    assert_mock_called "fstrim"
    /usr/bin/grep -qF -- "-va" "${MOCK_CALLS}/fstrim"
}

# ── package_cache_cleanup ────────────────────────────────────────────────────

@test "package cache: calls paccache with correct flags" {
    run package_cache_cleanup

    [ "$status" -eq 0 ]
    assert_mock_called "paccache"
    /usr/bin/grep -qF -- "-rk2" "${MOCK_CALLS}/paccache"
    /usr/bin/grep -qF -- "-ruk0" "${MOCK_CALLS}/paccache"
}

@test "package cache: skips when paccache not found" {
    rm -f "${MOCK_BIN}/paccache"
    export PATH="${MOCK_BIN}"

    run package_cache_cleanup

    [ "$status" -eq 0 ]
    [[ "$output" == *"skipped"* ]]
    [[ "$output" == *"paccache not found"* ]]
}

# ── orphan_removal ───────────────────────────────────────────────────────────

@test "orphans: skips when no orphans found" {
    mock_command pacman 1

    run orphan_removal

    [ "$status" -eq 0 ]
    [[ "$output" == *"No orphaned packages"* ]]
}

@test "orphans: removes found orphans" {
    mock_command pacman 0 "stale-pkg"

    run orphan_removal

    [ "$status" -eq 0 ]
    /usr/bin/grep -qF -- "Rns" "${MOCK_CALLS}/pacman"
}

# ── failed_units ─────────────────────────────────────────────────────────────

@test "failed units: reports clean when none" {
    mock_command systemctl 0 ""

    run failed_units

    [ "$status" -eq 0 ]
    [[ "$output" == *"No failed systemd units"* ]]
}

@test "failed units: warns when units are failing" {
    mock_command systemctl 0 "nginx.service loaded failed failed"

    run failed_units

    [ "$status" -eq 0 ]
    [[ "$output" == *"Failed units detected"* ]] || [[ "$output" == *"nginx"* ]]
}

# ── journal_vacuum ───────────────────────────────────────────────────────────

@test "journal vacuum: calls journalctl correctly" {
    run journal_vacuum

    [ "$status" -eq 0 ]
    assert_mock_called "journalctl"
    /usr/bin/grep -qF "vacuum-time=3d" "${MOCK_CALLS}/journalctl"
}

# ── limine_integrity ────────────────────────────────────────────────────────

@test "limine: detects config and kernel entry" {
    mock_command pacman 0
    mkdir -p "${TEST_TEMP}/boot"
    echo "vmlinuz-linux-cachyos" > "${TEST_TEMP}/boot/limine.conf"
    mock_command limine-entry-tool 0

    run limine_integrity

    [ "$status" -eq 0 ]
    [[ "$output" == *"limine.conf found"* ]]
    [[ "$output" == *"Kernel entry found"* ]]
}

@test "limine: warns when config missing" {
    mock_command pacman 0
    rm -f "${TEST_TEMP}/boot/limine.conf"

    run limine_integrity

    [ "$status" -eq 0 ]
    [[ "$output" == *"limine.conf not found"* ]]
}

@test "limine: warns when package not installed" {
    mock_command pacman 1

    run limine_integrity

    [ "$status" -eq 0 ]
    [[ "$output" == *"limine package not found"* ]]
}

@test "limine: warns when no kernel entry in config" {
    mock_command pacman 0
    mkdir -p "${TEST_TEMP}/boot"
    echo "# empty config" > "${TEST_TEMP}/boot/limine.conf"

    run limine_integrity

    [ "$status" -eq 0 ]
    [[ "$output" == *"No kernel entry"* ]]
}

@test "limine: reports limine-entry-tool missing" {
    mock_command pacman 0
    mkdir -p "${TEST_TEMP}/boot"
    echo "vmlinuz-linux-cachyos" > "${TEST_TEMP}/boot/limine.conf"
    rm -f "${MOCK_BIN}/limine-entry-tool"
    # Restrict PATH so system limine-entry-tool isn't found
    export PATH="${MOCK_BIN}"

    run limine_integrity

    [ "$status" -eq 0 ]
    [[ "$output" == *"not found"* ]] || [[ "$output" == *"manually"* ]]
}

# ── git_signing ──────────────────────────────────────────────────────────────

@test "git signing: detects configured signing key" {
    mock_command runuser 0 "ABC123"
    mock_command pgrep 0

    run git_signing

    [ "$status" -eq 0 ]
    [[ "$output" == *"Git signing key configured"* ]]
}

@test "git signing: configures GPG agent cache TTL" {
    mock_command runuser 0 "true"
    mock_command pgrep 0
    mock_command getent 0 "${USER}:x:1000:1000::${TEST_HOME}:/bin/bash"

    run git_signing

    [ "$status" -eq 0 ]
    [[ "$output" == *"GPG agent cache TTL"* ]]
}

@test "git signing: skips cache TTL when already configured" {
    mock_command runuser 0 "true"
    mock_command pgrep 0
    mock_command getent 0 "${USER}:x:1000:1000::${TEST_HOME}:/bin/bash"
    mkdir -p "${TEST_HOME}/.gnupg"
    echo "max-cache-ttl 604800" > "${TEST_HOME}/.gnupg/gpg-agent.conf"

    run git_signing

    [ "$status" -eq 0 ]
    [[ "$output" == *"already configured"* ]]
}

# ── shebang and standards ───────────────────────────────────────────────────

@test "maintenance: uses #!/usr/bin/env bash" {
    assert_shebang "$SCRIPTS_DIR/08-maintenance.sh"
}

@test "maintenance: no emoji in output" {
    assert_no_emoji "$SCRIPTS_DIR/08-maintenance.sh"
}
