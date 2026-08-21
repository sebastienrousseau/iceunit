---
description: Security-focused tooling including SOPS, Age, and Gitleaks, with UFW firewall configuration.
verifiedOn: 2026-04-01
---

# Security Tools

**Status: Optional**

The `30-security-tools.sh` script hardens the system and installs essential security utilities for secrets management and code auditing.

## Security Features

- **Firewall**: Enables and configures `UFW` with a "deny incoming, allow outgoing" default policy.
- **Secrets**: Installs `sops` and `age` for modern encrypted secrets management.
- **Auditing**: Provisions `gitleaks` to prevent accidental secret commits.
- **Communication**: Ensures `openssh` and `gnupg` are correctly configured.

## Running

```bash
sudo bash workstation/30-security-tools.sh
```

::: tip Source
View the full source on [GitHub](https://github.com/sebastienrousseau/iceunit/blob/main/workstation/30-security-tools.sh).
:::
