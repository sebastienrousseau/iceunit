# Test Suite Guide

## Architecture

```
tests/
  test_helper.bash          # Thin loader — sources all helpers + contracts
  helpers/
    common.bash             # Setup/teardown, mock framework, script prep
    mock_pacman.bash         # mock_all_packages_installed, mock_package_missing
    mock_systemctl.bash      # mock_service_enabled, mock_service_disabled, …
    assertions.bash          # then_status_ok, then_output_contains, …
    mock_mise_plugin.bash    # mock_uname, mock_curl_download
  contracts/
    standards.bash           # assert_shebang, assert_no_emoji
    package_install.bash     # assert_package_skip, assert_package_install
    service_enable.bash      # assert_service_skip_when_enabled, …
    dry_run.bash             # assert_dry_run_succeeds, assert_help_shows_usage
    summary.bash             # assert_summary_shows_items
    mise_plugin.bash         # assert_asdf_env_required
  *.bats                     # Test files — one per script
```

Every `.bats` file loads everything via `load test_helper`.

## When to use a contract

Use a contract when the test follows a **pattern that already exists** in `tests/contracts/`:

```bash
# Instead of 5 lines:
@test "fwupd: skips when installed" {
    mock_command pacman 0
    run setup_fwupd
    [ "$status" -eq 0 ]
    [[ "$output" == *"already installed"* ]]
}

# Write 1 line:
@test "fwupd: skips when installed" {
    assert_package_skip setup_fwupd "already installed"
}
```

Available contracts:

| Contract | Use when testing… |
|---|---|
| `assert_shebang` / `assert_no_emoji` | Script quality standards |
| `assert_package_skip` / `assert_package_install` | Package already-installed / install-when-missing |
| `assert_service_skip_when_enabled` / `assert_service_enables_when_disabled` | Service enable/skip logic |
| `assert_dry_run_succeeds` / `assert_help_shows_usage` | `--dry-run` and `--help` flags |
| `assert_summary_shows_items` | `print_summary` output |
| `assert_asdf_env_required` | Mise plugin env var validation |

## When to write a script-specific test

Write a custom test when the behaviour is **unique to that script** and doesn't match any contract. Examples:

- Testing a specific config file's contents (`grep -q "enable_guc=3"`)
- Verifying fallback logic (`paru` -> `yay` -> `pacman`)
- Checking filesystem side effects (file created, permissions set)
- Complex mock setups with multiple conditional commands

If you notice three or more `.bats` files repeating the same custom pattern, that's a signal to extract a new contract.

## How to add a new mock or helper

1. Check if the behaviour already exists in `tests/helpers/`. Don't duplicate.
2. Add the function to the **most specific existing file** that fits:
   - Pacman/package mocking -> `mock_pacman.bash`
   - Systemctl/service mocking -> `mock_systemctl.bash`
   - General assertions -> `assertions.bash`
   - Mise plugin mocking -> `mock_mise_plugin.bash`
   - Setup/teardown or core mock framework -> `common.bash`
3. If it doesn't fit any existing file, create a new `tests/helpers/<name>.bash` and add a `source` line to `test_helper.bash`.
4. Add `# shellcheck disable=SC2154` at the top if the function uses bats variables (`$status`, `$output`).

## How to add a new contract

1. Create `tests/contracts/<pattern>.bash`.
2. Add a `source` line to `test_helper.bash`.
3. Each function should encapsulate a complete test pattern: setup mocks, `run` the function, assert status and output.
4. Accept the variable parts as parameters (function name, package name, expected output).

## Avoiding duplication

Before writing test code, check:

- [ ] Is there a contract for this pattern? (`grep -r "assert_" tests/contracts/`)
- [ ] Is there a helper mock for this command? (`grep -r "mock_" tests/helpers/`)
- [ ] Does another `.bats` file test the same pattern? If 3+ files share it, extract a contract.
- [ ] Am I copying `mock_uname` or `mock_curl_download` into a new file? Use `mock_mise_plugin.bash` instead.

## Running tests

```bash
bats tests/*.bats          # All tests
bats tests/w05-desktop-base.bats  # Single file
```
