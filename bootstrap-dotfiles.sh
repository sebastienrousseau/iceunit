#!/usr/bin/env bash
set -Eeuo pipefail

REPO_URL="${DOTFILES_REPO_URL:-https://github.com/sebastienrousseau/dotfiles.git}"
DOTFILES_DIR="${DOTFILES_DIR:-$HOME/.dotfiles}"
BRANCH="${DOTFILES_BRANCH:-main}"

log() {
  printf '\n[%s] %s\n' "$(date '+%H:%M:%S')" "$*"
}

warn() {
  printf '\n[WARN] %s\n' "$*" >&2
}

die() {
  printf '\n[ERROR] %s\n' "$*" >&2
  exit 1
}

have() {
  command -v "$1" >/dev/null 2>&1
}

run_sudo() {
  if [[ "${EUID}" -ne 0 ]]; then
    sudo "$@"
  else
    "$@"
  fi
}

install_prereqs() {
  local missing=()
  have git || missing+=(git)
  have curl || missing+=(curl)

  (( ${#missing[@]} == 0 )) && return 0

  log "Installing prerequisites: ${missing[*]}"

  if have pacman; then
    run_sudo pacman -Sy --needed --noconfirm "${missing[@]}"
  elif have apt-get; then
    run_sudo apt-get update
    run_sudo apt-get install -y "${missing[@]}"
  elif have dnf; then
    run_sudo dnf install -y "${missing[@]}"
  elif have zypper; then
    run_sudo zypper install -y "${missing[@]}"
  elif have brew; then
    brew install "${missing[@]}"
  else
    die "No supported package manager found. Install manually: ${missing[*]}"
  fi
}

clone_or_update() {
  if [[ -d "$DOTFILES_DIR/.git" ]]; then
    log "Updating existing repo at $DOTFILES_DIR"
    git -C "$DOTFILES_DIR" fetch --all --prune
    git -C "$DOTFILES_DIR" checkout "$BRANCH"
    git -C "$DOTFILES_DIR" pull --ff-only origin "$BRANCH"
  elif [[ -e "$DOTFILES_DIR" ]]; then
    die "$DOTFILES_DIR exists but is not a git repository"
  else
    log "Cloning $REPO_URL into $DOTFILES_DIR"
    git clone --branch "$BRANCH" "$REPO_URL" "$DOTFILES_DIR"
  fi
}

run_install() {
  local installer="$DOTFILES_DIR/install.sh"

  [[ -f "$installer" ]] || die "Missing install.sh in $DOTFILES_DIR"
  chmod +x "$installer"

  log "Running install.sh"
  (
    cd "$DOTFILES_DIR"
    ./install.sh
  )
}

main() {
  log "Bootstrapping dotfiles"
  install_prereqs
  clone_or_update
  run_install
  log "Bootstrap complete"
}

main "$@"
