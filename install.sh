#!/usr/bin/env bash
# install.sh — idempotent Arch WSL bootstrap for ~/me/dotfiles
# Run as your user (never sudo ./install.sh).
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACMAN_LIST="$REPO/packages/pacman.txt"
AUR_LIST="$REPO/packages/aur.txt"
SOURCE_DIR="$REPO/home"
BACKUP_ROOT="${XDG_DATA_HOME:-$HOME/.local/share}/dotfiles-backup"
SKIP_DOCKER="${SKIP_DOCKER:-0}"
SKIP_LAZYDOCKER="${SKIP_LAZYDOCKER:-0}"

log()  { printf '==> %s\n' "$*"; }
warn() { printf 'warning: %s\n' "$*" >&2; }
die()  { printf 'error: %s\n' "$*" >&2; exit 1; }

need_cmd() { command -v "$1" >/dev/null 2>&1 || die "missing required command: $1"; }

# --- Preflight ---
[[ ${EUID:-$(id -u)} -eq 0 ]] && die "Do not run as root. Use: ./install.sh (sudo is invoked per-command)."

if [[ -r /etc/os-release ]]; then
  # shellcheck disable=SC1091
  . /etc/os-release
  [[ "${ID:-}" == "arch" ]] || die "This installer targets Arch Linux (got ID=${ID:-unknown})."
else
  die "Cannot read /etc/os-release"
fi

log "Refreshing sudo credentials (interactive OK)"
sudo -v || die "sudo required for pacman/systemctl/usermod"

# Keep sudo warm during long paru builds
( while true; do sleep 60; sudo -n true 2>/dev/null || exit; done ) &
SUDO_KEEPER_PID=$!
trap 'kill $SUDO_KEEPER_PID 2>/dev/null || true' EXIT

log "Ensuring bootstrap tools (git curl base-devel)"
sudo pacman -S --needed --noconfirm git curl base-devel

# --- Full sync ---
log "pacman -Syu (full sync before installs)"
sudo pacman -Syu --noconfirm

# --- paru ---
bootstrap_paru() {
  local tmp
  tmp="$(mktemp -d)"
  log "Bootstrapping paru (paru-bin) as user"
  (
    cd "$tmp"
    git clone --depth=1 https://aur.archlinux.org/paru-bin.git
    cd paru-bin
    makepkg -si --noconfirm
  )
  rm -rf "$tmp"
}

if ! command -v paru >/dev/null 2>&1; then
  if command -v yay >/dev/null 2>&1; then
    warn "paru missing; yay present — installing paru-bin via makepkg"
  fi
  bootstrap_paru
  need_cmd paru
else
  log "paru already present"
fi

# --- Official packages ---
filter_pacman_list() {
  local pkg
  while IFS= read -r pkg || [[ -n ${pkg:-} ]]; do
    pkg="${pkg%%#*}"
    pkg="$(echo "$pkg" | xargs)"
    [[ -z "$pkg" ]] && continue
    if [[ "$SKIP_DOCKER" == "1" ]] && [[ "$pkg" =~ ^(docker|docker-compose|docker-buildx)$ ]]; then
      continue
    fi
    if [[ "$SKIP_LAZYDOCKER" == "1" || "$SKIP_DOCKER" == "1" ]] && [[ "$pkg" == "lazydocker" ]]; then
      continue
    fi
    printf '%s\n' "$pkg"
  done <"$PACMAN_LIST"
}

log "Installing official packages (--needed)"
mapfile -t PKGS < <(filter_pacman_list)
if ((${#PKGS[@]})); then
  sudo pacman -S --needed --noconfirm "${PKGS[@]}"
fi

# --- AUR ---
log "Installing AUR packages (paru --sudoloop)"
mapfile -t AUR_PKGS < <(grep -vE '^\s*(#|$)' "$AUR_LIST" | sed 's/#.*//' | xargs -n1)
if ((${#AUR_PKGS[@]})); then
  paru -S --needed --sudoloop --noconfirm "${AUR_PKGS[@]}"
fi

# ble.sh fallback if AUR path missing
if [[ ! -f /usr/share/blesh/ble.sh ]]; then
  warn "blesh package did not provide /usr/share/blesh/ble.sh — cloning fallback"
  mkdir -p "$HOME/.local/share"
  if [[ ! -d "$HOME/.local/share/blesh" ]]; then
    git clone --recursive --depth=1 https://github.com/akinomyoga/ble.sh.git "$HOME/.local/share/blesh"
    make -C "$HOME/.local/share/blesh" install PREFIX="$HOME/.local"
  fi
fi

# --- Docker ---
DOCKER_GROUP_ADDED=0
if [[ "$SKIP_DOCKER" != "1" ]]; then
  log "Docker: enable service + group membership"
  if getent group docker >/dev/null 2>&1; then
    :
  else
    sudo groupadd docker
  fi
  if id -nG "$USER" | tr ' ' '\n' | grep -qx docker; then
    log "User already in docker group"
  else
    sudo usermod -aG docker "$USER"
    DOCKER_GROUP_ADDED=1
    log "Added $USER to docker group (re-login required)"
  fi
  sudo systemctl enable --now docker.service || warn "Could not enable docker.service (systemd?)"
fi

# --- External binaries (official scripts; skip if present) ---
install_herdr() {
  if command -v herdr >/dev/null 2>&1; then
    log "herdr already present: $(command -v herdr)"
    return
  fi
  log "Installing herdr (official script)"
  curl -fsSL https://herdr.dev/install.sh | sh
}

install_cursor_cli() {
  if command -v agent >/dev/null 2>&1 || command -v cursor-agent >/dev/null 2>&1; then
    log "Cursor CLI already present"
    return
  fi
  log "Installing Cursor CLI (official script)"
  curl https://cursor.com/install -fsS | bash
}

install_claude() {
  if command -v claude >/dev/null 2>&1; then
    log "Claude Code already present: $(command -v claude)"
    return
  fi
  log "Installing Claude Code (official script)"
  curl -fsSL https://claude.ai/install.sh | bash
}

install_herdr
install_cursor_cli
install_claude

if command -v opencode2 >/dev/null 2>&1 || command -v opencode-beta >/dev/null 2>&1; then
  log "OpenCode present — leaving alone (not installing extra/opencode)"
else
  warn "opencode2/opencode-beta not found; install manually if desired"
fi

# --- SSH prep ---
log "SSH prep (dirs, stable .pub names, config.local)"
mkdir -p "$HOME/.ssh"
chmod 700 "$HOME/.ssh"

# Stable public key names
if [[ -f "$HOME/.ssh/home-personal.pub" ]]; then
  :
elif [[ -f "$HOME/.ssh/id_ed25519.pub" ]]; then
  cp -n "$HOME/.ssh/id_ed25519.pub" "$HOME/.ssh/home-personal.pub" || true
fi

if [[ ! -f "$HOME/.ssh/vps.pub" ]]; then
  if [[ -f "$HOME/.ssh/vps_srv1938886.pub" ]]; then
    cp -n "$HOME/.ssh/vps_srv1938886.pub" "$HOME/.ssh/vps.pub" || true
    log "Copied vps_srv1938886.pub → vps.pub"
  fi
fi

touch "$HOME/.ssh/config.local"
chmod 600 "$HOME/.ssh/config.local"

# Seed VPS HostName/User into config.local if empty and old config has them
if ! grep -qE '^\s*HostName\s+' "$HOME/.ssh/config.local" 2>/dev/null; then
  if [[ -f "$HOME/.ssh/config" ]] && grep -q 'Host vps' "$HOME/.ssh/config"; then
    # Extract HostName/User from existing Host vps block (best-effort)
    awk '
      BEGIN{inblock=0}
      /^Host[ \t]+vps([ \t]|$)/ {inblock=1; next}
      /^Host[ \t]/ {if(inblock) exit}
      inblock && /^[ \t]*HostName[ \t]+/ {print}
      inblock && /^[ \t]*User[ \t]+/ {print}
    ' "$HOME/.ssh/config" >"$HOME/.ssh/config.local.tmp" || true
    if [[ -s "$HOME/.ssh/config.local.tmp" ]]; then
      {
        echo "Host vps"
        cat "$HOME/.ssh/config.local.tmp"
      } >>"$HOME/.ssh/config.local"
      log "Seeded VPS HostName/User into ~/.ssh/config.local from existing ssh config"
    fi
    rm -f "$HOME/.ssh/config.local.tmp"
  fi
fi

# --- Backup ---
TS="$(date +%Y%m%d-%H%M%S)"
BACKUP_DIR="$BACKUP_ROOT/$TS"
mkdir -p "$BACKUP_DIR"
log "Backing up existing dots → $BACKUP_DIR"
for f in \
  "$HOME/.bashrc" \
  "$HOME/.gitconfig" \
  "$HOME/.ssh/config" \
  "$HOME/.config/herdr/config.toml"
do
  if [[ -e "$f" ]]; then
    dest="$BACKUP_DIR/${f#"$HOME"/}"
    mkdir -p "$(dirname "$dest")"
    cp -a "$f" "$dest"
  fi
done

# --- Chezmoi ---
need_cmd chezmoi
if [[ -d "$HOME/.local/share/chezmoi" ]] || [[ -f "$HOME/.config/chezmoi/chezmoi.toml" ]]; then
  CURRENT_SOURCE="$(chezmoi source-path 2>/dev/null || true)"
  if [[ -n "$CURRENT_SOURCE" ]]; then
    CURRENT_REAL="$(realpath "$CURRENT_SOURCE" 2>/dev/null || echo "$CURRENT_SOURCE")"
    EXPECT_REAL="$(realpath "$SOURCE_DIR")"
    if [[ "$CURRENT_REAL" != "$EXPECT_REAL" ]]; then
      die "chezmoi source-path is '$CURRENT_SOURCE' (expected '$SOURCE_DIR'). Fix ~/.config/chezmoi/chezmoi.toml or: chezmoi init --source \"$SOURCE_DIR\""
    fi
    log "chezmoi already pointing at this repo"
  else
    log "Initializing chezmoi with source $SOURCE_DIR"
    chezmoi init --source "$SOURCE_DIR"
  fi
else
  log "Initializing chezmoi with source $SOURCE_DIR"
  chezmoi init --source "$SOURCE_DIR"
fi

log "chezmoi apply"
chezmoi apply --force

# --- mise globals ---
if command -v mise >/dev/null 2>&1; then
  log "mise trust + install (node@lts, python@latest)"
  mise trust "$HOME/.config/mise/config.toml" 2>/dev/null || true
  mise install || warn "mise install failed (non-fatal)"
fi

# --- Shell / dirs ---
mkdir -p "$HOME/work" "$HOME/.local/bin"
export PATH="$HOME/.local/bin:$PATH"

CURRENT_SHELL="$(getent passwd "$USER" | cut -d: -f7 || true)"
if [[ "$CURRENT_SHELL" != "/bin/bash" ]]; then
  log "Setting login shell to /bin/bash (current: $CURRENT_SHELL)"
  sudo chsh -s /bin/bash "$USER" || warn "chsh failed"
else
  log "Login shell already bash"
fi

# --- wsl.conf hint ---
if [[ -r /etc/wsl.conf ]] && grep -qi 'appendWindowsPath\s*=\s*true' /etc/wsl.conf; then
  warn "appendWindowsPath=true in /etc/wsl.conf can shadow Linux tools with *.exe"
  warn "See $REPO/config/wsl.conf.example (not applied automatically)"
fi

# --- Epilogue ---
cat <<EOF

--------------------------------------------------------------------
Install finished.

Next (manual):
  1. Unlock Arch Bitwarden desktop; enable SSH agent
  2. Import private keys into Bitwarden SSH; leave only .pub in ~/.ssh/
  3. Confirm ~/.ssh/config.local has VPS HostName/User
  4. Add home-personal.pub as a GitHub/GitLab Signing key
  5. Open a new login shell (docker group + bashrc)
  6. Until BW agent is ready, use: git commit --no-gpg-sign

Backup: $BACKUP_DIR
Verify:  $REPO/verify.sh
--------------------------------------------------------------------
EOF

if [[ "$DOCKER_GROUP_ADDED" == "1" ]]; then
  warn "Docker group just added — use: sg docker -c 'docker info' until re-login"
fi

if [[ ! -S "$HOME/.bitwarden-ssh-agent.sock" ]]; then
  warn "Bitwarden SSH socket missing — unlock Bitwarden before ssh/git signing"
fi

"$REPO/verify.sh" || warn "verify.sh reported issues (see above)"
