#!/usr/bin/env bash
# =============================================================================
# test_helper.bash — Thin loader: sources all helpers and contracts
# =============================================================================
# All .bats files continue to use `load test_helper` — this file sources the
# modular helpers and contracts so everything is available automatically.

_HELPER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/helpers" && pwd)"
_CONTRACT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/contracts" && pwd)"

# Layer 1: Helpers
# shellcheck source=helpers/common.bash
source "${_HELPER_DIR}/common.bash"
# shellcheck source=helpers/mock_pacman.bash
source "${_HELPER_DIR}/mock_pacman.bash"
# shellcheck source=helpers/mock_systemctl.bash
source "${_HELPER_DIR}/mock_systemctl.bash"
# shellcheck source=helpers/assertions.bash
source "${_HELPER_DIR}/assertions.bash"
# shellcheck source=helpers/mock_mise_plugin.bash
source "${_HELPER_DIR}/mock_mise_plugin.bash"

# Layer 2: Contracts
# shellcheck source=contracts/standards.bash
source "${_CONTRACT_DIR}/standards.bash"
# shellcheck source=contracts/package_install.bash
source "${_CONTRACT_DIR}/package_install.bash"
# shellcheck source=contracts/service_enable.bash
source "${_CONTRACT_DIR}/service_enable.bash"
# shellcheck source=contracts/dry_run.bash
source "${_CONTRACT_DIR}/dry_run.bash"
# shellcheck source=contracts/summary.bash
source "${_CONTRACT_DIR}/summary.bash"
# shellcheck source=contracts/mise_plugin.bash
source "${_CONTRACT_DIR}/mise_plugin.bash"
