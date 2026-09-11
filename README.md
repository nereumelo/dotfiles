# Dotfiles (Arch Linux WSL)

Chezmoi-managed devops environment for **Arch in WSL**. Local git repo only for now — does **not** replace [github.com/nereumelo/dotfiles](https://github.com/nereumelo/dotfiles).

**Stack:** Bash + ble.sh + starship + mise + direnv · UX CLIs (zoxide, fzf, eza, atuin, bat, glow, fd, ripgrep, bottom, sd, jq, go-yq) · WezTerm · Herdr · OpenCode2 · Cursor CLI · Claude Code · Neovim · Docker · Bitwarden SSH + SSH commit signing · Tokyo Night theme

## Repository layout

```
dotfiles/
├── install.sh / verify.sh     # package + machine bootstrap only
├── packages/pacman.txt|aur.txt
├── config/wsl.conf.example
└── home/                      # chezmoi sourceDir → applied into ~
    ├── .chezmoidata.toml      # theme + non-secret git defaults
    ├── dot_*                  # → ~/.*
    ├── private_dot_config/    # → ~/.config/…
    ├── private_dot_ssh/       # → ~/.ssh/… (config, allowed_signers)
    └── run_once_after_*.sh    # post-apply hooks (no package installs)
```

| Chezmoi source | Target |
|----------------|--------|
| `dot_bashrc` | `~/.bashrc` |
| `dot_blerc` | `~/.blerc` |
| `dot_gitconfig.tmpl` | `~/.gitconfig` |
| `private_dot_config/bash/` | `~/.config/bash/` |
| `private_dot_config/git/config-work.tmpl` | `~/.config/git/config-work` |
| `private_dot_config/nvim/` | `~/.config/nvim/` |
| `private_dot_ssh/config.tmpl` | `~/.ssh/config` |
| `dot_local/bin/executable_theme` | `~/.local/bin/theme` |

`install.sh` owns packages. Chezmoi never installs packages.

## Day 0 — install

1. Repo at `~/me/dotfiles` (this tree).
2. Run **as your user** (not root):

   ```bash
   ./install.sh
   ```

   Sudo is prompted for pacman / systemctl / usermod / chsh only.
3. Unlock **Arch** Bitwarden → enable SSH agent → import keys → fill `~/.ssh/config.local` for VPS (checklist below).
4. `./verify.sh`
5. Open a **new login shell** (bash + docker group).
6. Optional: apply notes from `config/wsl.conf.example` (`appendWindowsPath=false`), then `wsl --shutdown` from Windows.
7. Per repo: add `.envrc` + `direnv allow` when needed; projects may also use `mise.toml`.

Env flags: `SKIP_DOCKER=1`, `SKIP_LAZYDOCKER=1`.

## Day N — edit dots

- Edit under `home/` or `chezmoi edit ~/.bashrc`
- Aliases/functions: `home/private_dot_config/bash/aliases.sh` / `functions.sh`, then `chezmoi apply`
- Machine-only: `~/.config/bash/aliases.local.sh` (untracked)
- `chezmoi diff` / `chezmoi apply`
- `theme` / `theme tokyo-night` / `theme catppuccin`
- Re-run `./install.sh` is safe for packages; routine dots still go through chezmoi
- `./verify.sh` after big changes

bashrc **sources** aliases from `~/.config/bash/` — it does not embed them. Use `\ls` / `\cat` for the real binaries.

## Privileges

Never: `sudo ./install.sh`, `sudo chezmoi`, `sudo paru`, `sudo mise`.

Sudo only for system pacman, system units, usermod, chsh.

## Git / SSH / signing

- Personal identity from `.chezmoidata.toml`; work via `includeIf "gitdir:~/work/"` → `~/.config/git/config-work`
- `EDITOR` / `VISUAL` / `GIT_EDITOR=nvim` from bashrc (no `core.editor`)
- SSH commit signing with `~/.ssh/home-personal.pub`; agent via `SSH_AUTH_SOCK=~/.bitwarden-ssh-agent.sock`
- VPS **HostName/User only** in `~/.ssh/config.local` (gitignored)

### VPS / key migration checklist

1. `touch ~/.ssh/config.local && chmod 600 ~/.ssh/config.local`
2. Put HostName/User under `Host vps` in `config.local` (install may seed from old `~/.ssh/config`)
3. Stable pubs: `home-personal.pub`, `vps.pub` (install copies `vps_srv1938886.pub` → `vps.pub` when present)
4. Import private keys into Bitwarden SSH; enable agent; unlock
5. `ssh -T git@github.com` and `ssh vps`
6. Remove private key files from `~/.ssh/` (leave `.pub` only)
7. Add the same pubkey as a GitHub/GitLab **Signing key**
8. Until the agent is ready: `git commit --no-gpg-sign`

Bitwarden vault syncs via your account across Windows/Arch clients. Enable the SSH agent in the **Arch** desktop app. Do not bridge Windows `npiperelay` into WSL for this setup.

## Themes

Default **Tokyo Night**. `theme` lists keys; `theme <name>` updates `.chezmoidata.toml` and runs `chezmoi apply` (WezTerm, Starship, Herdr, Neovim). Reload GUI apps if colors look stale.

## Toolchains

- mise globals: `node@lts`, `python@latest` (`mise install` after apply)
- direnv hook after mise; allow `.envrc` per repo
- Agents: Herdr, Cursor CLI (`agent`), Claude Code (`claude`), keep existing OpenCode2 / opencode-beta

## Out of scope

No Windows host automation · no fish · no LazyVim · rootful Docker without `daemon.json` · atuin cloud sync off · herdr/Cursor/Claude versions not pinned (upstream scripts) · no silent `/etc/wsl.conf` rewrite
