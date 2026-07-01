#!/bin/bash
set -euo pipefail

# Install herdr
curl -fsSL https://herdr.dev/install.sh | sh

# Fish setup (must run in fish, not bash)
fish -c 'set -U fish_greeting'
fish -c 'fish_add_path ~/.local/bin'
fish -c 'curl -sL https://raw.githubusercontent.com/jorgebucaran/fisher/main/functions/fisher.fish | source && fisher install jorgebucaran/fisher'
fish -c 'fisher install IlanCosman/tide@v6 jethrokuan/z PatrickF1/fzf.fish jorgebucaran/nvm.fish jorgebucaran/replay.fish'

# Agent CLIs
curl https://cursor.com/install -fsS | bash
curl -fsSL https://claude.ai/install.sh | bash
curl -fsSL https://opencode.ai/install | bash