# Contributing

Contributions are welcome. This guide covers the conventions and process for submitting changes.

## Script Conventions

All scripts in `scripts/` follow these rules:

- **Shebang:** `#!/usr/bin/env bash` — never rely on the calling shell
- **Strict mode:** `set -euo pipefail` — exit on error, undefined variables, or pipe failures
- **Colour output:** use `[INFO]`, `[OK]`, `[WARN]`, `[ERROR]` prefixes with ANSI colours — no emoji
- **`--dry-run` flag:** every script must support `--dry-run` to preview actions without modifying the system
- **`--help` flag:** every script must display usage information with `--help`
- **Path discovery:** use `find` instead of glob patterns (globs fail under `sudo bash` in fish shell)
- **Mount detection:** use `findmnt` instead of `mount | grep`
- **Idempotent:** safe to run multiple times — back up existing configs before overwriting
- **Header comment block:** include a description, hardware context, and purpose at the top of every script

## ShellCheck

All scripts must pass [ShellCheck](https://www.shellcheck.net/). The CI pipeline runs ShellCheck automatically on every push and pull request that touches `scripts/*.sh` or `tests/**`.

Run locally before submitting:

```bash
make lint
```

A `.shellcheckrc` is included in the repository root with project-wide defaults.

## Testing

The project uses [bats-core](https://github.com/bats-core/bats-core) for unit testing and Docker-based integration tests. All tests run automatically in CI.

### Running Tests Locally

```bash
make test-all           # Lint + unit + Go + Docker + integration tests
make lint               # ShellCheck + Go vet
make test               # Unit tests locally (requires bats-core)
make test-go            # Go unit tests for the installer
make test-docker        # Unit tests in Arch Linux Docker
make test-integration   # Integration tests in Arch Linux Docker
```

Run `make help` to see all available targets.

### Writing Tests

Unit tests live in `tests/*.bats`. Each script has a corresponding test file. The shared `tests/test_helper.bash` provides:

- `common_setup` / `common_teardown` — isolated temp directories, mock `$PATH`, mock `$HOME`
- `mock_command` / `mock_command_multiline` / `mock_command_conditional` — create mock binaries
- `assert_mock_called` / `assert_mock_called_with` / `assert_mock_not_called` — verify interactions
- `source_script` / `prepare_script` — safely source scripts with system paths redirected to temp dirs

New scripts must include corresponding unit tests and pass integration tests before merging.

## Documentation

The documentation site is built with [VitePress](https://vitepress.dev/) and lives in `docs/`.

### Local Development

```bash
npm install
make docs            # Start dev server at localhost:5173
make docs-build      # Build for production
make docs-preview    # Build and preview
```

### Writing Script Docs

Each script has a corresponding page at `docs/scripts/<name>.md`. Follow the existing template:

1. Title and one-paragraph description
2. Usage section with invocation command
3. What It Does (ordered list of actions)
4. Options / Modes (if applicable)
5. Files Modified table
6. Prerequisites
7. Source tip box linking to GitHub

## Pull Request Process

1. Fork the repository and create a branch from `main`
2. Make your changes following the conventions above
3. Ensure `make lint` passes
4. Ensure `make test` passes (or `make test-docker`)
5. Ensure `make docs-build` succeeds if you changed documentation
6. Submit a pull request with a clear description of the change and its motivation
7. One approval from a maintainer is required before merging

## Reporting Issues

Open an issue on GitHub for bugs, documentation errors, or hardware compatibility reports. Include your kernel version (`uname -r`) and relevant `dmesg` output when reporting hardware issues.
