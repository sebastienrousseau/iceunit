#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

log() {
  printf '\033[1;36mRunning the Iceunit (ICU) installer...\033[0m\n'
}

cd "$ROOT_DIR/installer"

if ! command -v go >/dev/null 2>&1; then
  printf '\n[ERROR] Go is not installed. Please install Go (e.g., sudo pacman -S go) to use the new interactive installer.\n'
  exit 1
fi

if [[ $EUID -ne 0 ]]; then
  printf '\n\033[1;33m[WARN]\033[0m Many scripts require root privileges. It is recommended to run with: sudo make install\n'
fi

log
go run main.go --yes "$@"
