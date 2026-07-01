#!/bin/bash
set -euo pipefail

#install herdr
set -U fish_greeting
curl -fsSL https://herdr.dev/install.sh | sh
fish_add_path /home/nereu/.local/bin

curl -sL https://raw.githubusercontent.com/jorgebucaran/fisher/main/functions/fisher.fish | source && fisher install jorgebucaran/fisher

fisher install IlanCosman/tide@v6 jethrokuan/z PatrickF1/fzf.fish jorgebucaran/nvm.fish jorgebucaran/replay.fish

# Agent CLIs
curl https://cursor.com/install -fsS | bash
curl -fsSL https://claude.ai/install.sh | bash
curl -fsSL https://opencode.ai/install | bash