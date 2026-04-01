# Security Policy

## Scope

This repository contains shell scripts and documentation for configuring CachyOS on MacBook Air 2020 hardware. The scripts modify system configuration files, manage firmware, and handle an encrypted code vault.

## Reporting a Vulnerability

If you discover a security issue in any script or configuration, please report it responsibly:

1. **Do not** open a public GitHub issue for security vulnerabilities
2. Email **security@iceunit.com** with a description of the issue
3. Include the affected file(s), line number(s), and a description of the impact
4. You will receive an acknowledgement within 48 hours

## Security Considerations

### LUKS2 Encrypted Vault

The vault scripts (`00-setup-vault.sh`, `05-mount-vault.sh`, `06-unmount-vault.sh`) handle LUKS2 encryption with the following parameters:

| Parameter | Value |
|---|---|
| Type | LUKS2 |
| Cipher | `aes-xts-plain64` |
| Key size | 512 bits |
| Hash | SHA-512 |
| KDF | Argon2id |

- The vault passphrase **cannot be recovered** if lost. There is no backdoor or recovery mechanism.
- The vault image (`~/.vault.img`) should **not** be added to `/etc/fstab` — it causes boot delays and potential failures.
- Back up `~/.vault.img` to a secure location. If the file is corrupted, all data inside is lost.

### Firmware Downloads

`02-wifi-firmware.sh install-pkg` downloads firmware from `mirror.funami.tech`. This is the official arch-mact2 community mirror. If you have concerns about supply chain integrity, use the macOS extraction method instead (`02-wifi-firmware.sh guide`).

### Script Execution

- All scripts that modify system files require `sudo`
- Scripts follow `set -Eeuo pipefail` — they exit on any error, with inherited ERR traps
- No script sends data to external services (except `02-wifi-firmware.sh install-pkg` which downloads firmware)
- ShellCheck CI runs on all pull requests to catch common shell scripting issues

## Supported Versions

Only the latest version on the `main` branch is supported. See the [changelog](https://iceunit.com/changelog) for release history.

### Dotfiles Bootstrap

`bootstrap-dotfiles.sh` clones and executes the `install.sh` from a remote dotfiles repository (`DOTFILES_REPO_URL`). The target repo is user-configurable and its contents are executed without signature or checksum verification. Only use trusted repositories.
