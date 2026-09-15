#!/usr/bin/env bash
# .cursor/install.sh — Cloud Agent bootstrap for the dotfiles repo.
#
# This repo is an Arch-Linux/WSL chezmoi dotfiles tree; its own install.sh and
# bootstrap.sh intentionally refuse to run anywhere but Arch. Cloud Agents run on
# Ubuntu, so this script installs only the host-agnostic tooling needed to edit
# and validate the chezmoi source: chezmoi (render/apply dotfiles) and shellcheck
# (lint the bash scripts). It never mutates the agent's real dotfiles.
#
# Idempotent: safe to run repeatedly.
set -euo pipefail

log() { printf '==> %s\n' "$*"; }

CHEZMOI_VERSION="2.52.0"
SHELLCHECK_VERSION="0.10.0"
BIN_DIR="/usr/local/bin"

install_chezmoi() {
  if command -v chezmoi >/dev/null 2>&1; then
    log "chezmoi already present: $(chezmoi --version | head -n1)"
    return
  fi
  log "Installing chezmoi ${CHEZMOI_VERSION} → ${BIN_DIR}"
  sudo sh -c "$(curl -fsLS get.chezmoi.io)" -- -b "$BIN_DIR" -t "v${CHEZMOI_VERSION}"
}

install_shellcheck() {
  if command -v shellcheck >/dev/null 2>&1; then
    log "shellcheck already present: $(shellcheck --version | awk '/version:/{print $2; exit}')"
    return
  fi
  log "Installing shellcheck ${SHELLCHECK_VERSION}"
  local tmp arch tarball
  arch="$(uname -m)"
  tmp="$(mktemp -d)"
  tarball="shellcheck-v${SHELLCHECK_VERSION}.linux.${arch}.tar.xz"
  if curl -fsSL -o "$tmp/sc.tar.xz" \
      "https://github.com/koalaman/shellcheck/releases/download/v${SHELLCHECK_VERSION}/${tarball}"; then
    tar -xJf "$tmp/sc.tar.xz" -C "$tmp"
    sudo install -m 0755 "$tmp/shellcheck-v${SHELLCHECK_VERSION}/shellcheck" "$BIN_DIR/shellcheck"
  else
    log "GitHub download failed; falling back to apt"
    sudo apt-get update -y
    sudo apt-get install -y shellcheck
  fi
  rm -rf "$tmp"
}

install_chezmoi
install_shellcheck

log "Tool versions:"
chezmoi --version | head -n1
shellcheck --version | awk '/version:/{print "shellcheck " $2; exit}'

log "Cloud Agent dotfiles environment ready."
