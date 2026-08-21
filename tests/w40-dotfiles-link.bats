#!/usr/bin/env bats

load test_helper

setup() {
    common_setup
    prepare_runnable_script "workstation/40-dotfiles-link.sh"
}

teardown() { common_teardown; }

@test "dotfiles: runs without error when no dotfiles dir exists" {
    run bash "$RUNNABLE_SCRIPT" --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" == *"Dotfiles linking complete"* ]]
}

@test "dotfiles: creates config directory" {
    run bash "$RUNNABLE_SCRIPT" --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" == *"DRY-RUN"* ]] || [ -d "${HOME}/.config" ]
}

@test "dotfiles: links nvim config when present" {
    mkdir -p "${HOME}/.dotfiles/config/nvim"
    run bash "$RUNNABLE_SCRIPT" --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" == *"nvim"* ]]
}

@test "dotfiles: links starship config when present" {
    mkdir -p "${HOME}/.dotfiles/config"
    touch "${HOME}/.dotfiles/config/starship.toml"
    run bash "$RUNNABLE_SCRIPT" --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" == *"starship"* ]]
}

@test "dotfiles: skips existing symlinks" {
    mkdir -p "${HOME}/.dotfiles/config/nvim"
    mkdir -p "${HOME}/.config"
    ln -s "${HOME}/.dotfiles/config/nvim" "${HOME}/.config/nvim"
    run bash "$RUNNABLE_SCRIPT"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Skipping existing"* ]]
}
