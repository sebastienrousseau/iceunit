.PHONY: help install bootstrap lint test test-go test-docker test-integration \
       test-all verify docs docs-build docs-preview clean \
       init vault thermal wifi optimise bootloader mount unmount apps maintenance \
       backup auto-fix \
       desktop ai-dev gnome-tweaks devops security dotfiles mise-plugins

SHELL := /bin/bash

# Pass DRY_RUN=1 to preview script actions without modifying the system
ifdef DRY_RUN
FLAGS := --dry-run
else
FLAGS :=
endif

# ── Help ─────────────────────────────────────────────────────────────────────

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*##' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*## "}; {printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2}'

# ── Install ──────────────────────────────────────────────────────────────────

install: ## Run the interactive Go-based installer (supports DRY_RUN=1)
	./install.sh $(FLAGS)

bootstrap: ## Bootstrap dotfiles from remote repo
	./bootstrap-dotfiles.sh

# ── Scripts (run individually, supports DRY_RUN=1) ───────────────────────────

init: ## Smart package synchronisation (00-system-init.sh)
	sudo bash scripts/00-system-init.sh $(FLAGS)

vault: ## Create LUKS2 encrypted vault (00-setup-vault.sh)
	bash scripts/00-setup-vault.sh $(FLAGS)

thermal: ## Fix fan/thermal control (01-thermal-setup.sh)
	sudo bash scripts/01-thermal-setup.sh $(FLAGS)

wifi: ## Manage Wi-Fi/BT firmware (02-wifi-firmware.sh)
	bash scripts/02-wifi-firmware.sh $(FLAGS)

optimise: ## Apply system optimisations (03-optimise.sh)
	sudo bash scripts/03-optimise.sh $(FLAGS)

bootloader: ## Manage Limine & boot order (04-bootloader.sh)
	sudo bash scripts/04-bootloader.sh $(FLAGS)

mount: ## Unlock and mount code vault (05-mount-vault.sh)
	bash scripts/05-mount-vault.sh $(FLAGS)

unmount: ## Lock and unmount code vault (06-unmount-vault.sh)
	bash scripts/06-unmount-vault.sh $(FLAGS)

apps: ## Standard application suite (07-install-apps.sh)
	bash scripts/07-install-apps.sh $(FLAGS)

maintenance: ## Periodic maintenance (08-maintenance.sh)
	sudo bash scripts/08-maintenance.sh $(FLAGS)

backup: ## Back up Wi-Fi/BT firmware (02-wifi-firmware.sh backup)
	bash scripts/02-wifi-firmware.sh backup

auto-fix: ## Verify and auto-fix failed checks (99-verify-install.sh --auto-fix)
	sudo bash scripts/99-verify-install.sh --auto-fix

# ── Workstation (run individually, supports DRY_RUN=1) ───────────────────────

desktop: ## Desktop foundation — GNOME, fonts, timers (05-desktop-base.sh)
	sudo bash workstation/05-desktop-base.sh $(FLAGS)

ai-dev: ## AI/LLM & developer stack (00-ai-dev-workstation.sh)
	sudo bash workstation/00-ai-dev-workstation.sh $(FLAGS)

gnome-tweaks: ## GNOME productivity tweaks (10-gnome-productivity.sh)
	bash workstation/10-gnome-productivity.sh $(FLAGS)

devops: ## DevOps & cloud-native tools (20-devops-tools.sh)
	sudo bash workstation/20-devops-tools.sh $(FLAGS)

security: ## Firewall & secrets hardening (30-security-tools.sh)
	sudo bash workstation/30-security-tools.sh $(FLAGS)

dotfiles: ## Link dotfiles symlinks (40-dotfiles-link.sh)
	bash workstation/40-dotfiles-link.sh $(FLAGS)

mise-plugins: ## Mise plugin infrastructure for AI tools (50-mise-plugins.sh)
	bash workstation/50-mise-plugins.sh $(FLAGS)

# ── Lint ─────────────────────────────────────────────────────────────────────

lint: ## Run ShellCheck on all scripts and Go lint
	shellcheck scripts/*.sh workstation/*.sh mise-plugins/*/bin/*
	cd installer && go vet ./... && go fmt ./...

# ── Test ─────────────────────────────────────────────────────────────────────

test: ## Run unit tests locally (requires bats-core)
	bats tests/*.bats

test-go: ## Run Go unit tests for the installer
	cd installer && go test ./... -v

test-docker: ## Run unit tests in Arch Linux Docker container
	docker build -f tests/Dockerfile.unit -t cachyos-unit-tests .
	docker run --rm cachyos-unit-tests

test-integration: ## Run integration tests in Arch Linux Docker container
	docker build -f tests/Dockerfile.integration -t cachyos-integration-tests .
	docker run --rm cachyos-integration-tests

test-all: lint test test-go test-docker test-integration ## Run lint, unit tests, and integration tests

verify: ## Verify the health of the entire Iceunit installation
	bash scripts/99-verify-install.sh

# ── Docs ─────────────────────────────────────────────────────────────────────

docs: ## Start VitePress dev server
	npm run docs:dev

docs-build: ## Build VitePress site for production
	npm run docs:build

docs-preview: docs-build ## Build and preview VitePress site
	npm run docs:preview

# ── Clean ────────────────────────────────────────────────────────────────────

clean: ## Remove build artifacts
	rm -rf docs/.vitepress/dist docs/.vitepress/cache node_modules
