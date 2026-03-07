.PHONY: help install bootstrap lint test test-go test-docker test-integration \
       test-all docs docs-build docs-preview clean \
       vault thermal wifi optimise bootloader mount unmount

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

install: ## Run the interactive Go-based installer
	./install.sh

bootstrap: ## Bootstrap dotfiles from remote repo
	./bootstrap-dotfiles.sh

# ── Scripts (run individually, supports DRY_RUN=1) ───────────────────────────

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

# ── Lint ─────────────────────────────────────────────────────────────────────

lint: ## Run ShellCheck on all scripts and Go lint
	shellcheck scripts/*.sh
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
