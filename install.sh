#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

log() {
  printf '\n[%s] %s\n' "$(date '+%H:%M:%S')" "$*"
}

run_scripts() {
  local dir="$1"
  local label="$2"

  shopt -s nullglob
  local scripts=("$dir"/[0-9][0-9]-*.sh)
  shopt -u nullglob

  if (( ${#scripts[@]} == 0 )); then
    log "No numbered scripts found in $label ($dir), skipping"
    return 0
  fi

  for script in "${scripts[@]}"; do
    log "Running $label/$(basename "$script")"
    bash "$script"
  done
}

run_scripts "$ROOT_DIR/scripts" "scripts"
run_scripts "$ROOT_DIR/workstation" "workstation"

log "Install complete"
