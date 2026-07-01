#!/bin/bash
set -euo pipefail

curl -fsSL https://herdr.dev/install.sh | sh
export PATH="${HOME}/.local/bin:${PATH}"

mkdir -p "${HOME}/.config/fish/functions"
curl -fsSL https://raw.githubusercontent.com/jorgebucaran/fisher/main/functions/fisher.fish \
  -o "${HOME}/.config/fish/functions/fisher.fish"

fish -c 'set -U fish_greeting'
fish -c 'fish_add_path ~/.local/bin'
fish -c 'fisher install jorgebucaran/fisher IlanCosman/tide@v6 jethrokuan/z PatrickF1/fzf.fish jorgebucaran/nvm.fish jorgebucaran/replay.fish'

curl -fsSL https://cursor.com/install | bash
curl -fsSL https://claude.ai/install.sh | bash
curl -fsSL https://opencode.ai/install | bash