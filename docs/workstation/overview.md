---
description: Overview of workstation provisioning scripts for AI, DevOps, and Security.
---

# Workstation Overview

In addition to the core hardware scripts, the repository includes a suite of workstation provisioning scripts located in the `workstation/` directory.

## Available Modules

| Script | Purpose | Status | Run As | Docs |
|---|---|---|---|---|
| [`00-ai-dev-workstation.sh`](/workstation/00-ai-dev-workstation) | AI/LLM & Dev Stack | Optional | `sudo` | [Reference](/workstation/00-ai-dev-workstation) |
| [`10-gnome-productivity.sh`](/workstation/10-gnome-productivity) | GNOME Speed & UI Tweaks | Optional | User | [Reference](/workstation/10-gnome-productivity) |
| [`20-devops-tools.sh`](/workstation/20-devops-tools) | K8s & Terraform Stack | Optional | `sudo` | [Reference](/workstation/20-devops-tools) |
| [`30-security-tools.sh`](/workstation/30-security-tools) | Firewall & Secrets | Optional | `sudo` | [Reference](/workstation/30-security-tools) |
| [`40-dotfiles-link.sh`](/workstation/40-dotfiles-link) | Symbolic Config Links | Optional | User | [Reference](/workstation/40-dotfiles-link) |

## Integration

All workstation scripts are integrated into the primary **Iceunit (ICU) Installer**. When you run `sudo make install`, these modules are executed in sequence following the hardware optimizations.

## Design Principles

- **Developer First**: Tools are chosen for modern, high-performance engineering workflows.
- **System-Aware**: Scripts detect existing configurations and skip redundant steps.
- **Idempotent**: Safe to run multiple times without side effects.
