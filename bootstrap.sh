#!/usr/bin/env bash
# bootstrap.sh — root bootstrap for Arch WSL dotfiles
# Run as root inside a fresh Arch WSL session.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_SH="$REPO/install.sh"
VERIFY_SH="$REPO/verify.sh"
DEFAULT_USER="${DEFAULT_USER:-}"

log()  { printf '==> %s\n' "$*"; }
warn() { printf 'warning: %s\n' "$*" >&2; }
die()  { printf 'error: %s\n' "$*" >&2; exit 1; }

need_cmd() { command -v "$1" >/dev/null 2>&1 || die "missing required command: $1"; }

pick_user() {
  local u="${1:-${DEFAULT_USER:-}}"
  if [[ -n "$u" ]]; then
    printf '%s\n' "$u"
    return 0
  fi

  if [[ -t 0 ]]; then
    read -r -p "Target username to create/use: " u
    [[ -n "$u" ]] || die "username is required"
    printf '%s\n' "$u"
    return 0
  fi

  die "set DEFAULT_USER=<name> or pass the username as the first argument"
}

ensure_group() {
  local group="$1"
  if getent group "$group" >/dev/null 2>&1; then
    return 0
  fi
  log "Creating group: $group"
  groupadd "$group"
}

ensure_user() {
  local user="$1"
  if id "$user" >/dev/null 2>&1; then
    log "User already exists: $user"
  else
    log "Creating user: $user"
    useradd -m -s /bin/bash "$user"
  fi
}

ensure_sudoers() {
  local user="$1"
  local sudoers_file="/etc/sudoers.d/90-$user-bootstrap"
  log "Configuring sudo for $user"
  install -d -m 0755 /etc/sudoers.d
  cat >"$sudoers_file" <<EOF
$user ALL=(ALL) NOPASSWD:ALL
EOF
  chmod 0440 "$sudoers_file"
  visudo -cf "$sudoers_file" >/dev/null
}

ensure_basic_perms() {
  local user="$1"
  local home_dir
  home_dir="$(getent passwd "$user" | cut -d: -f6)"
  [[ -n "$home_dir" ]] || die "cannot determine home directory for $user"

  log "Preparing basic permissions in $home_dir"
  install -d -m 0700 -o "$user" -g "$user" "$home_dir"
  install -d -m 0700 -o "$user" -g "$user" "$home_dir/.ssh"
  install -d -m 0755 -o "$user" -g "$user" "$home_dir/.local" "$home_dir/.local/bin" "$home_dir/.config"
}

main() {
  [[ ${EUID:-$(id -u)} -eq 0 ]] || die "Run bootstrap.sh as root"

  need_cmd pacman
  need_cmd useradd
  need_cmd usermod
  need_cmd visudo
  need_cmd install
  need_cmd getent

  local target_user
  target_user="$(pick_user "${1:-}")"

  log "Refreshing package database"
  pacman -Sy --noconfirm

  log "Installing base admin tools"
  pacman -S --needed --noconfirm sudo shadow util-linux grep coreutils

  ensure_group wheel
  ensure_user "$target_user"
  usermod -aG wheel "$target_user"
  ensure_sudoers "$target_user"
  ensure_basic_perms "$target_user"

  log "Bootstrap complete"
  cat <<EOF

Next step:
  log out of root and run as the normal user:
    $INSTALL_SH

Optional check:
    $VERIFY_SH

Current user prepared:
  $target_user
EOF
}

main "$@"
