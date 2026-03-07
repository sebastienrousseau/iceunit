#!/usr/bin/env bash
# =============================================================================
# setup-bats.sh — Download bats-core for running tests locally
# =============================================================================
set -euo pipefail

TESTS_DIR="$(cd "$(dirname "$0")" && pwd)"
LIB_DIR="${TESTS_DIR}/lib"

mkdir -p "$LIB_DIR"

for repo in bats-core bats-support bats-assert; do
    if [[ ! -d "${LIB_DIR}/${repo}" ]]; then
        echo "Downloading ${repo}..."
        git clone --depth 1 "https://github.com/bats-core/${repo}.git" "${LIB_DIR}/${repo}"
    else
        echo "${repo} already present"
    fi
done

echo ""
echo "Setup complete. Run tests with:"
echo "  ${LIB_DIR}/bats-core/bin/bats tests/*.bats"
echo ""
echo "Or via npm:"
echo "  npm test"
