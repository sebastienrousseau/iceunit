---
description: Essential DevOps tooling including Kubernetes (kubectl, helm, k9s) and Terraform.
---

# DevOps Tools

**Status: Optional**

The `20-devops-tools.sh` script installs a modern DevOps toolchain, ensuring your MacBook Air is ready for cloud-native engineering.

## Tools Installed

- **Kubernetes**: `kubectl`, `helm`, `k9s`, `stern`, and `dive`.
- **Infrastructure**: `terraform` and `ansible`.
- **Utilities**: `rsync` for efficient file synchronization.

## Features

- **Auto-completion**: Automatically generates and installs bash completion for `kubectl`.
- **System-wide**: Installs tools via `pacman` for easy updates.

## Running

```bash
sudo bash workstation/20-devops-tools.sh
```
