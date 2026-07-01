#!/bin/bash
set -euo pipefail

# Install herdr
curl -fsSL https://herdr.dev/install.sh | sh

# Install fisher directly (no fish -c, no nested quotes)
mkdir -p "${HOME}/.config/fish/functions"
curl -fsSL https://raw.githubusercontent.com/jorgebucaran/fisher/main/functions/fisher.fish \
  -o "${HOME}/.config/fish/functions/fisher.fish"

# Fish setup via a temp script — avoids quoting issues with curl | bash
fish_setup="$(mktemp /tmp/fish-setup.XXXXXX.fish)"
cat > "${fish_setup}" << 'FISH'
set -U fish_greeting
fish_add_path ~/.local/bin
fisher install jorgebucaran/fisher IlanCosman/tide@v6 jethrokuan/z PatrickF1/fzf.fish jorgebucaran/nvm.fish jorgebucaran/replay.fish
FISH
fish "${fish_setup}"
rm -f "${fish_setup}"

# Agent CLIs (bash only — must stay OUTSIDE any fish block)
curl -fsSL https://cursor.com/install | bash
curl -fsSL https://claude.ai/install.sh | bash
curl -fsSL https://opencode.ai/install | bash