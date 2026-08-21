#!/usr/bin/env bash
# =============================================================================
# mock_pacman.bash — Higher-level DSL wrappers for pacman mocking
# =============================================================================

# Mock all packages as installed (pacman -Qq echoes back queried package names)
mock_all_packages_installed() {
    cat > "${MOCK_BIN}/pacman" << ENDMOCK
#!/usr/bin/env bash
echo "\$*" >> "${MOCK_CALLS}/pacman"
for arg in "\$@"; do
    case "\$arg" in -*|--*) continue ;; *) echo "\$arg" ;; esac
done
exit 0
ENDMOCK
    chmod +x "${MOCK_BIN}/pacman"
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
