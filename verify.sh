#!/usr/bin/env bash
# verify.sh — soft checks for the ~/me/dotfiles stack
set -uo pipefail

PASS=0
FAIL=0
WARN=0

ok()   { printf '  [ok]   %s\n' "$*"; PASS=$((PASS + 1)); }
bad()  { printf '  [FAIL] %s\n' "$*"; FAIL=$((FAIL + 1)); }
soft() { printf '  [warn] %s\n' "$*"; WARN=$((WARN + 1)); }

have() { command -v "$1" >/dev/null 2>&1; }

echo "== Commands =="
for c in \
  bash chezmoi mise starship nvim zoxide fzf eza atuin bat glow fd rg btm sd jq yq \
  direnv docker git ssh
do
  if have "$c"; then ok "$c → $(command -v "$c")"
  else bad "missing: $c"
  fi
done

echo
echo "== Optional agents =="
if have herdr; then ok "herdr present"; else soft "herdr not on PATH"; fi
if have agent || have cursor-agent; then ok "Cursor CLI present"; else soft "Cursor CLI (agent) not on PATH"; fi
if have claude; then ok "Claude Code present"; else soft "claude not on PATH"; fi
if have opencode2 || have opencode-beta; then ok "OpenCode present"; else soft "opencode2/opencode-beta not on PATH"; fi
if [[ -f /usr/share/blesh/ble.sh ]] || [[ -f "$HOME/.local/share/blesh/ble.sh" ]]; then ok "ble.sh present"; else soft "ble.sh missing"; fi

echo
echo "== Configs deployed =="
for f in \
  "$HOME/.bashrc" \
  "$HOME/.blerc" \
  "$HOME/.gitconfig" \
  "$HOME/.ssh/config" \
  "$HOME/.ssh/config.local" \
  "$HOME/.ssh/allowed_signers" \
  "$HOME/.config/bash/aliases.sh" \
  "$HOME/.config/bash/functions.sh" \
  "$HOME/.config/starship.toml" \
  "$HOME/.config/herdr/config.toml" \
  "$HOME/.config/mise/config.toml" \
  "$HOME/.config/nvim/init.lua" \
  "$HOME/.local/bin/theme"
do
  if [[ -e "$f" ]]; then ok "$f"; else soft "missing: $f"; fi
done

echo
echo "== Git signing =="
if git config --global --get gpg.format 2>/dev/null | grep -qx ssh; then
  ok "gpg.format=ssh"
else
  soft "gpg.format not ssh (signing may be inactive until home-personal.pub exists)"
fi
if [[ -f "$HOME/.ssh/home-personal.pub" ]]; then
  ok "home-personal.pub present"
else
  soft "home-personal.pub missing — signing templates skipped"
fi
if git config --global --get commit.gpgsign 2>/dev/null | grep -qi true; then
  ok "commit.gpgsign=true"
  soft "Commits fail until Bitwarden agent unlocked (or use --no-gpg-sign)"
fi

echo
echo "== SSH / Bitwarden =="
if [[ -S "$HOME/.bitwarden-ssh-agent.sock" ]]; then
  ok "Bitwarden SSH socket present"
else
  soft "No socket at ~/.bitwarden-ssh-agent.sock — unlock Arch Bitwarden"
fi
if [[ -z "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ]]; then
  soft "No DISPLAY/WAYLAND_DISPLAY — Bitwarden GUI/agent may need WSLg"
fi

echo
echo "== Docker =="
if have docker; then
  if docker version >/dev/null 2>&1; then
    ok "docker client OK"
  else
    soft "docker client error"
  fi
  if docker info >/dev/null 2>&1; then
    ok "docker daemon reachable"
  elif sg docker -c 'docker info' >/dev/null 2>&1; then
    ok "docker daemon OK via sg docker"
    soft "Re-login for docker group in this shell"
  else
    soft "docker daemon not reachable (service/group?)"
  fi
  if have docker-compose || docker compose version >/dev/null 2>&1; then
    ok "docker compose OK"
  else
    soft "docker compose missing"
  fi
else
  soft "docker not installed (SKIP_DOCKER?)"
fi

echo
echo "== Chezmoi source =="
if have chezmoi; then
  src="$(chezmoi source-path 2>/dev/null || true)"
  expect="$(realpath "$(dirname "$0")/home" 2>/dev/null || true)"
  src_real="$(realpath "$src" 2>/dev/null || echo "$src")"
  if [[ -n "$src" && -n "$expect" && "$src_real" == "$expect" ]]; then
    ok "source-path → $src"
  else
    soft "source-path='$src' (expected $expect)"
  fi
fi

echo
echo "== Summary: $PASS ok, $WARN warn, $FAIL fail =="
[[ "$FAIL" -eq 0 ]]
