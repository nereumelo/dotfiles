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
if [[ -x "$HOME/.opencode/bin/opencode" ]]; then
  ok "OpenCode 2 → $HOME/.opencode/bin/opencode"
elif have opencode; then
  soft "opencode at $(command -v opencode) (want v2 at ~/.opencode/bin/opencode, not extra/opencode 1.x)"
else
  soft "opencode not on PATH"
fi
if [[ -f /usr/share/blesh/ble.sh ]] || [[ -f "$HOME/.local/share/blesh/ble.sh" ]]; then ok "ble.sh present"; else soft "ble.sh missing"; fi
if grep -q "completion-ignore-case on" "$HOME/.blerc" 2>/dev/null; then
  ok "ble.sh completion-ignore-case on"
else
  soft "~/.blerc missing completion-ignore-case (chezmoi apply?)"
fi

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
  "$HOME/.config/opencode/tui.json" \
  "$HOME/.local/bin/theme" \
  "$HOME/.local/bin/windows-open" \
  "$HOME/.local/bin/bitwarden-ssh-notify" \
  "$HOME/.local/bin/xdg-open"
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
if [[ -S "$HOME/.bitwarden-ssh-agent-notify.sock" ]]; then
  ok "Bitwarden SSH notify proxy socket present"
else
  soft "No notify proxy socket — chezmoi apply / systemctl --user enable --now bitwarden-ssh-notify"
fi
if have python3; then ok "python3 → $(command -v python3)"; else soft "python3 missing — bitwarden-ssh-notify"; fi
if have xdotool; then ok "xdotool → $(command -v xdotool)"; else soft "xdotool missing — cannot raise Bitwarden window"; fi
if [[ -f "$HOME/.ssh/config" ]] && grep -qE '^Include[[:space:]]+config\.local' "$HOME/.ssh/config"; then
  ok "ssh config Includes config.local"
else
  soft "$HOME/.ssh/config does not Include config.local (chezmoi apply?)"
fi
if grep -qE '^ssh-manage\(\)' "$HOME/.config/bash/functions.sh" 2>/dev/null; then
  ok "ssh-manage() in functions.sh"
else
  soft "ssh-manage() missing — chezmoi apply?"
fi
if grep -qE '^ssh-host-local\(\)|^ssh-pub\(\)' "$HOME/.config/bash/functions.sh" 2>/dev/null; then
  soft "ssh-host-local/ssh-pub still public — chezmoi apply? use ssh-manage"
fi
if [[ -f "$HOME/.ssh/config.local" ]] && grep -qE '^Host[[:space:]]+github\.com([[:space:]]|$)' "$HOME/.ssh/config.local"; then
  ok "config.local has Host github.com"
else
  soft "config.local missing Host github.com — ssh-manage (Set Host)"
fi
if [[ -f "$HOME/.ssh/home-personal.pub" ]]; then
  if grep -qE '^[[:space:]]*IdentityFile[[:space:]]+' "$HOME/.ssh/config" 2>/dev/null; then
    ok "IdentityFile in ~/.ssh/config (ssh-manage)"
  else
    soft "home-personal.pub present but IdentityFile not in ~/.ssh/config — ssh-manage (Set Public Key)"
  fi
  if grep -qE '^[[:space:]]*IdentityFile[[:space:]]+' "$HOME/.ssh/config.local" 2>/dev/null; then
    soft "IdentityFile still in config.local — ssh-manage Set Public Key to move it into config"
  fi
fi
if [[ -z "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ]]; then
  soft "No DISPLAY/WAYLAND_DISPLAY — Bitwarden GUI/agent may need WSLg"
fi

echo
echo "== Windows browser (WSL) =="
if [[ -x "$HOME/.local/bin/windows-open" ]]; then
  ok "windows-open → $HOME/.local/bin/windows-open"
else
  soft "windows-open missing (chezmoi apply?)"
fi
if grep -qE '^copy\(\)' "$HOME/.config/bash/functions.sh" 2>/dev/null; then
  ok "copy() in functions.sh"
else
  soft "copy() missing — chezmoi apply?"
fi
if grep -qE '^open\(\)' "$HOME/.config/bash/functions.sh" 2>/dev/null; then
  ok "open() in functions.sh"
else
  soft "open() missing — chezmoi apply?"
fi
if [[ -x /mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe ]] \
  || [[ -x /mnt/c/Windows/System32/cmd.exe ]]; then
  ok "Windows interop (powershell/cmd under /mnt/c/Windows)"
else
  soft "no powershell.exe/cmd.exe under /mnt/c/Windows — WSL interop off?"
fi
if have xclip; then
  ok "xclip → $(command -v xclip)"
else
  soft "xclip missing — copy() uses the X11 clipboard (pacman extra/xclip)"
fi
if [[ -n "${DISPLAY:-}" || -n "${WAYLAND_DISPLAY:-}" ]]; then
  ok "WSLg display DISPLAY=${DISPLAY-} WAYLAND_DISPLAY=${WAYLAND_DISPLAY-}"
else
  soft "no DISPLAY/WAYLAND_DISPLAY — copy() needs WSLg"
fi
if [[ -x /mnt/c/Windows/explorer.exe ]] || [[ -x /mnt/c/Windows/System32/explorer.exe ]]; then
  ok "explorer.exe under /mnt/c/Windows"
else
  soft "no explorer.exe under /mnt/c/Windows — open() needs WSL interop"
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
