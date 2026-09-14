#!/usr/bin/env bash
# bootstrap.sh — in-distro root first-boot for Arch WSL (user, sudo, packages, chezmoi).
#
# Preferred Day 0 (from Windows, not Linux):
#   irm https://raw.githubusercontent.com/nereumelo/dotfiles/main/bootstrap.ps1 | iex
#
# Already inside the distro as root:
#   pacman-key --init && pacman-key --populate archlinux && \
#     pacman -Syu --noconfirm archlinux-keyring curl && \
#     curl -fsSL https://raw.githubusercontent.com/nereumelo/dotfiles/main/bootstrap.sh | bash
#
# Already have curl:
#   curl -fsSL https://raw.githubusercontent.com/nereumelo/dotfiles/main/bootstrap.sh | bash
#
# Non-interactive:
#   WSL_USER=you WSL_PASSWORD='...' curl -fsSL ... | bash
#
# Optional env: DOTFILES_REPO DOTFILES_REF DOTFILES_DIR SKIP_DOCKER SKIP_LAZYDOCKER
# Skip the user-level installer: DOTFILES_SKIP_INSTALL=1
# WezTerm is a Windows app (see bootstrap.ps1 / windows/wezterm.lua). Not installed here.
set -euo pipefail

# This WSL session still has the default Windows PATH until restart.
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
export GIT_TERMINAL_PROMPT=0

DOTFILES_REPO="${DOTFILES_REPO:-https://github.com/nereumelo/dotfiles.git}"
DOTFILES_REF="${DOTFILES_REF:-main}"
SKIP_INSTALL="${DOTFILES_SKIP_INSTALL:-0}"
NOPASSWD_FILE="/etc/sudoers.d/99-dotfiles-bootstrap"

log()  { printf '==> %s\n' "$*"; }
warn() { printf 'warning: %s\n' "$*" >&2; }
die()  { printf 'error: %s\n' "$*" >&2; exit 1; }

have_tty() { [[ -r /dev/tty ]]; }

read_tty() {
  local -n __dest=$1
  IFS= read -r -p "$2" __dest </dev/tty
}

read_tty_secret() {
  local -n __dest=$1
  IFS= read -r -s -p "$2" __dest </dev/tty
  echo >&2
}

usage() {
  cat <<'EOF'
bootstrap.sh — in-distro root first-boot for Arch WSL dotfiles

Preferred Day 0 is Windows: irm https://raw.githubusercontent.com/nereumelo/dotfiles/main/bootstrap.ps1 | iex

Run this script as root inside distro "arch". Prompts for username/password
unless WSL_USER and WSL_PASSWORD are set, then creates the user, clones the
repo to ~/me/dotfiles, and runs install.sh as that user. Does not install WezTerm.

Already inside Arch as root:
  pacman-key --init && pacman-key --populate archlinux && \
    pacman -Syu --noconfirm archlinux-keyring curl && \
    curl -fsSL https://raw.githubusercontent.com/nereumelo/dotfiles/main/bootstrap.sh | bash
EOF
}

is_wsl() {
  [[ -n "${WSL_DISTRO_NAME:-}" ]] && return 0
  [[ -e /proc/sys/fs/binfmt_misc/WSLInterop ]] && return 0
  grep -qiE 'microsoft|wsl' /proc/version 2>/dev/null && return 0
  return 1
}

local_repo_from_script() {
  local src="${BASH_SOURCE[0]:-}"
  local dir
  [[ "$(basename "$src")" == "bootstrap.sh" && -f "$src" ]] || return 1
  dir="$(cd "$(dirname "$src")" && pwd)"
  [[ -f "$dir/install.sh" && -d "$dir/home" ]] || return 1
  printf '%s\n' "$dir"
}

valid_username() {
  local name=$1
  [[ "$name" =~ ^[a-z_][a-z0-9_-]{0,31}$ ]] || return 1
  [[ "$name" != "root" ]] || return 1
}

prompt_user() {
  local user="${WSL_USER:-${DOTFILES_USER:-}}"
  if [[ -z "$user" ]]; then
    have_tty || die "No TTY. Set WSL_USER and WSL_PASSWORD, then re-run."
    read_tty user "Username: "
    while ! valid_username "$user"; do
      read_tty user "Username (lowercase, not root): "
    done
  elif ! valid_username "$user"; then
    die "invalid username: $user"
  fi
  printf '%s\n' "$user"
}

prompt_password() {
  local existing=$1 password="${WSL_PASSWORD:-${DOTFILES_PASSWORD:-}}" password_confirm
  if [[ -n "$password" ]]; then
    printf '%s\n' "$password"
    return 0
  fi
  if [[ "$existing" == "1" ]]; then
    return 1
  fi
  have_tty || die "No TTY. Set WSL_USER and WSL_PASSWORD, then re-run."
  while true; do
    read_tty_secret password "Password: "
    read_tty_secret password_confirm "Confirm password: "
    if [[ -z "$password" ]]; then
      echo "Password cannot be empty." >&2
    elif [[ "$password" != "$password_confirm" ]]; then
      echo "Passwords do not match. Try again." >&2
    else
      printf '%s\n' "$password"
      return 0
    fi
  done
}

ensure_keyring() {
  log "Initializing pacman keyring"
  pacman-key --init
  pacman-key --populate archlinux
  if ! pacman -Syu --noconfirm archlinux-keyring; then
    warn "pacman-key sync failed; resetting /etc/pacman.d/gnupg"
    rm -rf /etc/pacman.d/gnupg
    pacman-key --init
    pacman-key --populate archlinux
    pacman -Syu --noconfirm archlinux-keyring
  fi
}

write_sudoers() {
  local file=$1 content=$2
  local tmp
  tmp="$(mktemp)"
  printf '%s\n' "$content" >"$tmp"
  chmod 0440 "$tmp"
  visudo -cf "$tmp" >/dev/null || {
    rm -f "$tmp"
    die "invalid sudoers content for $file"
  }
  install -d -m 0755 /etc/sudoers.d
  install -m 0440 "$tmp" "$file"
  rm -f "$tmp"
}

cleanup_nopasswd() {
  rm -f "$NOPASSWD_FILE"
}

# runuser does not set HOME/USER unless --login; inherit would keep root's env
# and Windows-shadowed PATH from the still-running first WSL session.
as_user() {
  local owner=$1
  shift
  local home
  command -v runuser >/dev/null 2>&1 || die "missing runuser (util-linux)"
  home="$(getent passwd "$owner" | cut -d: -f6)"
  [[ -n "$home" ]] || die "cannot determine home for $owner"
  runuser -u "$owner" -- env \
    HOME="$home" \
    USER="$owner" \
    LOGNAME="$owner" \
    SHELL=/bin/bash \
    GIT_TERMINAL_PROMPT=0 \
    LANG="${LANG:-en_US.UTF-8}" \
    PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin" \
    "$@"
}

sync_repo() {
  local dest=$1 owner=$2 local_repo=${3:-}
  local parent src_real dest_real grp
  grp="$(id -gn "$owner")"
  parent="$(dirname "$dest")"
  install -d -m 0755 -o "$owner" -g "$grp" "$parent"

  if [[ -n "$local_repo" ]]; then
    src_real="$(realpath "$local_repo")"
    dest_real="$(realpath "$dest" 2>/dev/null || true)"
    if [[ -n "$dest_real" && "$src_real" == "$dest_real" ]]; then
      log "Repo already at $dest"
      chown -R "$owner:" "$dest"
      return
    fi
    log "Copying local repo $local_repo → $dest"
    mkdir -p "$dest"
    cp -a "$local_repo"/. "$dest"/
    chown -R "$owner:" "$dest"
    return
  fi

  if [[ -d "$dest/.git" ]]; then
    log "Updating $dest ($DOTFILES_REF)"
    as_user "$owner" git -C "$dest" fetch --depth=1 origin "$DOTFILES_REF"
    as_user "$owner" git -C "$dest" checkout -B "$DOTFILES_REF" FETCH_HEAD
    return
  fi

  if [[ -e "$dest" ]]; then
    die "$dest exists and is not a git checkout"
  fi

  log "Cloning $DOTFILES_REPO ($DOTFILES_REF) → $dest"
  as_user "$owner" git clone --depth=1 --branch "$DOTFILES_REF" "$DOTFILES_REPO" "$dest"
}

write_wsl_conf() {
  local user=$1
  log "Writing /etc/wsl.conf (default user ${user}, systemd, Linux PATH first)"
  cat >/etc/wsl.conf <<EOF
[boot]
systemd=true

[user]
default=${user}

[interop]
enabled=true
appendWindowsPath=false
EOF
}

main() {
  case "${1:-}" in
    -h|--help) usage; exit 0 ;;
  esac

  [[ ${EUID:-$(id -u)} -eq 0 ]] || die "Run as root (fresh Arch WSL). As your user: ./install.sh"

  if [[ -r /etc/os-release ]]; then
    # shellcheck disable=SC1091
    . /etc/os-release
    [[ "${ID:-}" == "arch" ]] || die "This bootstrap targets Arch Linux (got ID=${ID:-unknown})."
  else
    die "Cannot read /etc/os-release"
  fi

  local user existing=0 password="" home dest local_repo=""
  user="$(prompt_user)"
  if id -u "$user" >/dev/null 2>&1; then
    existing=1
    log "User '${user}' already exists"
  fi
  if password="$(prompt_password "$existing")"; then
    :
  else
    password=""
  fi

  ensure_keyring
  log "Installing root bootstrap packages (sudo git curl)"
  pacman -S --needed --noconfirm sudo git curl

  if [[ "$existing" -eq 1 ]]; then
    usermod -aG wheel -s /bin/bash "$user"
  else
    log "Creating user '${user}'"
    useradd -m -G wheel -s /bin/bash "$user"
  fi
  if [[ -n "$password" ]]; then
    echo "${user}:${password}" | chpasswd
  fi
  unset password
  unset WSL_PASSWORD DOTFILES_PASSWORD

  write_sudoers /etc/sudoers.d/10-wheel '%wheel ALL=(ALL:ALL) ALL'

  home="$(getent passwd "$user" | cut -d: -f6)"
  [[ -n "$home" && -d "$home" ]] || die "cannot determine home for $user"
  dest="${DOTFILES_DIR:-$home/me/dotfiles}"

  sed -i 's/^#\?\s*en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
  locale-gen
  echo "LANG=en_US.UTF-8" >/etc/locale.conf

  if is_wsl; then
    write_wsl_conf "$user"
  else
    warn "Not WSL; skipping /etc/wsl.conf"
  fi

  local_repo="$(local_repo_from_script || true)"
  sync_repo "$dest" "$user" "$local_repo"
  [[ -f "$dest/install.sh" ]] || die "install.sh missing in $dest"

  if [[ "$SKIP_INSTALL" == "1" ]]; then
    log "DOTFILES_SKIP_INSTALL=1 — not running install.sh"
  else
    log "Granting temporary passwordless sudo for first install"
    write_sudoers "$NOPASSWD_FILE" "${user} ALL=(ALL:ALL) NOPASSWD: ALL"
    trap cleanup_nopasswd EXIT
    log "Running install.sh as ${user}"
    as_user "$user" env \
      SKIP_DOCKER="${SKIP_DOCKER:-0}" \
      SKIP_LAZYDOCKER="${SKIP_LAZYDOCKER:-0}" \
      bash "$dest/install.sh"
    cleanup_nopasswd
    trap - EXIT
  fi

  cat <<EOF

--------------------------------------------------------------------
Bootstrap finished.

Repo:    $dest
User:    $user  (wheel, bash, password sudo)

From Windows:
  wsl --shutdown
then reopen the distro — you should land as ${user}.

Later updates (as ${user}, never sudo):
  $dest/install.sh
--------------------------------------------------------------------
EOF
}

main "$@"
