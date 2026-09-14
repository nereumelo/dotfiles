# ~/.config/bash/aliases.sh — simple aliases only (edit here, then chezmoi apply)
# Escape hatch: \ls \cat \vim for the real binary.

# --- fs ---
alias ls='eza --group-directories-first --icons=auto'
alias ll='eza -l --group-directories-first --icons=auto --git'
alias la='eza -la --group-directories-first --icons=auto --git'
alias tree='eza --tree --group-directories-first --icons=auto'

# --- text ---
alias cat='bat -p'
alias batp='bat -p'

# --- editor ---
alias vim='nvim'

# --- git ---
alias g='git'
alias gs='git status -sb'
alias gd='git diff'
alias gds='git diff --staged'
alias ga='git add'
alias gc='git commit'
alias gp='git push'
alias gl='git log --oneline -n 20'

# --- docker ---
alias d='docker'
alias dc='docker compose'
alias dps='docker ps'
alias ld='lazydocker'
