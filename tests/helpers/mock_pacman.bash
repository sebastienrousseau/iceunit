#!/usr/bin/env bash
# =============================================================================
# mock_pacman.bash — Higher-level DSL wrappers for pacman mocking
# =============================================================================

# Mock all packages as installed (pacman -Q succeeds)
mock_all_packages_installed() {
    mock_command pacman 0
}

# Mock all packages as missing (pacman -Q fails)
mock_all_packages_missing() {
    mock_command pacman 1
}

# Mock a specific package as missing while others succeed
# Usage: mock_package_missing <package_name>
mock_package_missing() {
    local pkg="$1"
    mock_command_conditional pacman "$pkg" 1 0
}
