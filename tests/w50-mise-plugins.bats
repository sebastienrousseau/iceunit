#!/usr/bin/env bats

load test_helper

setup() {
    common_setup
    prepare_runnable_script "workstation/50-mise-plugins.sh"
    mock_command pacman 0
    mock_command mise 0 "2024.1.0"

    # Create fake plugin directories so register_and_install finds them
    local script_dir
    script_dir="$(dirname "$RUNNABLE_SCRIPT")"
    mkdir -p "${script_dir}/../mise-plugins/ollama/bin"
    mkdir -p "${script_dir}/../mise-plugins/claude-code/bin"
    mkdir -p "${script_dir}/../mise-plugins/droid-factory/bin"
}

teardown() { common_teardown; }

@test "mise-plugins: runs in dry-run mode without error" {
    run bash "$RUNNABLE_SCRIPT" --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" == *"DRY-RUN"* ]]
}

@test "mise-plugins: detects existing mise installation" {
    run bash "$RUNNABLE_SCRIPT" --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" == *"mise already installed"* ]]
}

@test "mise-plugins: falls back to pacman when mise missing" {
    rm -f "${MOCK_BIN}/mise"
    local patched="${TEST_TEMP}/patched_mise.sh"
    {
        echo '#!/usr/bin/env bash'
        echo 'command() { if [[ "$1" == "-v" && "$2" == "mise" ]]; then return 1; fi; builtin command "$@"; }'
        tail -n +2 "$RUNNABLE_SCRIPT"
    } > "$patched"
    chmod +x "$patched"
    run bash "$patched" --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" == *"pacman"* ]]
}

@test "mise-plugins: registers ollama plugin" {
    run bash "$RUNNABLE_SCRIPT" --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" == *"Registering local ollama plugin"* ]]
}

@test "mise-plugins: registers claude-code plugin" {
    run bash "$RUNNABLE_SCRIPT" --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" == *"Registering local claude-code plugin"* ]]
}

@test "mise-plugins: registers droid-factory plugin" {
    run bash "$RUNNABLE_SCRIPT" --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" == *"Registering local droid-factory plugin"* ]]
}

@test "mise-plugins: installs all tools via mise" {
    run bash "$RUNNABLE_SCRIPT" --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" == *"ollama@latest"* ]]
    [[ "$output" == *"claude-code@latest"* ]]
    [[ "$output" == *"droid-factory@latest"* ]]
}

@test "mise-plugins: prints completion message" {
    run bash "$RUNNABLE_SCRIPT" --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" == *"complete"* ]]
}

@test "mise-plugins: --help prints usage and exits" {
    run bash "$RUNNABLE_SCRIPT" --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"Usage"* ]]
    [[ "$output" == *"--dry-run"* ]]
    [[ "$output" == *"--help"* ]]
}

@test "mise-plugins: warns when plugin directory missing" {
    local script_dir
    script_dir="$(dirname "$RUNNABLE_SCRIPT")"
    rm -rf "${script_dir}/../mise-plugins/ollama"

    run bash "$RUNNABLE_SCRIPT" --dry-run
    [[ "$output" == *"WARN"* ]]
    [[ "$output" == *"not found"* ]]
}

@test "mise-plugins: detects WSL and shows browser auth hint" {
    local patched="${TEST_TEMP}/patched_wsl.sh"
    sed "s|/proc/version|${TEST_TEMP}/proc/version|g" "$RUNNABLE_SCRIPT" > "$patched"
    chmod +x "$patched"
    echo "Linux version 5.15.0-1-microsoft-standard-WSL2" > "${TEST_TEMP}/proc/version"

    run bash "$patched" --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" == *"WSL detected"* ]]
    [[ "$output" == *"xdg-utils"* ]]
}

@test "mise-plugins: executes commands in non-dry-run mode" {
    run bash "$RUNNABLE_SCRIPT"
    [ "$status" -eq 0 ]
    assert_mock_called mise
    # No DRY-RUN markers in output
    [[ "$output" != *"DRY-RUN"* ]]
}

@test "mise-plugins: uses #!/usr/bin/env bash" {
    head -1 "${WORKSTATION_DIR}/50-mise-plugins.sh" | grep -q '#!/usr/bin/env bash'
}
