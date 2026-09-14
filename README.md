# Dotfiles (Arch Linux WSL)

Chezmoi-managed devops environment for **Arch in WSL**. Local git repo only for now — does **not** replace [github.com/nereumelo/dotfiles](https://github.com/nereumelo/dotfiles).

**Stack:** Bash + ble.sh + starship + mise + direnv · UX CLIs (zoxide, fzf, eza, atuin, bat, glow, fd, ripgrep, bottom, sd, jq, go-yq) · Windows WezTerm → WSL `arch` · Herdr · OpenCode2 · Cursor CLI · Claude Code · Neovim · Docker · Bitwarden SSH + SSH commit signing · Tokyo Night theme

## Repository layout

```
dotfiles/
├── bootstrap.ps1              # Day 0 from Windows (WSL distro arch + WezTerm + Linux bootstrap)
├── bootstrap.sh               # in-distro root first-boot (user, sudo, packages, chezmoi)
├── install.sh / verify.sh     # package + machine bootstrap as your Linux user
├── windows/wezterm.lua        # copied to %USERPROFILE%\.config\wezterm\wezterm.lua
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

`install.sh` owns packages. Chezmoi never installs packages. WezTerm is not an Arch package.

## Day 0 — Windows first

From **Windows PowerShell or Windows Terminal** (your Windows user, not a Linux shell):

```powershell
irm https://raw.githubusercontent.com/nereumelo/dotfiles/main/bootstrap.ps1 | iex
```

Or from a checkout:

```powershell
powershell -ExecutionPolicy Bypass -File .\bootstrap.ps1
```

`bootstrap.ps1`:

1. Installs/ensures WSL2
2. Installs the official Arch WSL distro **named `arch`** (`wsl -l` shows `arch`, not `archlinux`). Reuses it if it already exists
3. Installs **Windows** WezTerm (`winget install wez.wezterm`) and JetBrainsMono Nerd Font
4. Writes `%USERPROFILE%\.config\wezterm\wezterm.lua` with `default_domain = "WSL:arch"` (Tokyo Night, JetBrainsMono Nerd Font, `hide_tab_bar_if_only_one_tab`, new windows in `~`)
5. Opens distro `arch` as root and runs `bootstrap.sh` (same in-distro path as below)

Non-interactive Linux user creation: set `WSL_USER` / `WSL_PASSWORD` in that PowerShell session before running the script.

When it finishes, open **Windows WezTerm**. You should land in the Linux home directory.

### Already inside the distro as root

Skip Windows if WSL `arch` and WezTerm are already set up:

```bash
pacman-key --init && pacman-key --populate archlinux && pacman -Syu --noconfirm archlinux-keyring curl && curl -fsSL https://raw.githubusercontent.com/nereumelo/dotfiles/main/bootstrap.sh | bash
```

If `curl` already works:

```bash
curl -fsSL https://raw.githubusercontent.com/nereumelo/dotfiles/main/bootstrap.sh | bash
```

Non-interactive:

```bash
WSL_USER=yourname WSL_PASSWORD='…' curl -fsSL https://raw.githubusercontent.com/nereumelo/dotfiles/main/bootstrap.sh | bash
```

`bootstrap.sh` prompts for a username and password, then:

1. Repairs the pacman keyring and installs `sudo` + `git`
2. Creates the user (`wheel`, bash), sudoers, `en_US.UTF-8`, and `/etc/wsl.conf` (systemd, that user as default, `appendWindowsPath=false`)
3. Clones this repo to `~/me/dotfiles` (or copies the local tree if you ran `bootstrap.sh` from a checkout)
4. Runs `./install.sh` as that user (packages, paru, chezmoi, tools) — **not** Linux WezTerm

Already the target user with the repo cloned? Skip root bootstrap:

```bash
./install.sh
```

Sudo is prompted for pacman / systemctl / usermod / chsh only. Env flags: `SKIP_DOCKER=1`, `SKIP_LAZYDOCKER=1`. Root-only machine setup: `DOTFILES_SKIP_INSTALL=1`.

Then:

1. Unlock **Arch** Bitwarden → enable SSH agent → import keys → fill `~/.ssh/config.local` for VPS (checklist below).
2. `./verify.sh`
3. Open a **new WezTerm window** (bash + docker group).
4. Per repo: add `.envrc` + `direnv allow` when needed; projects may also use `mise.toml`.

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

Day 0: `bootstrap.ps1` as your **Windows** user, then `bootstrap.sh` as **root** inside `arch`.

Never: `sudo ./install.sh`, `sudo chezmoi`, `sudo paru`, `sudo mise`.

Sudo only for system pacman, system units, usermod, chsh. Linux bootstrap grants passwordless sudo only while `install.sh` runs, then restores password `wheel` sudo.

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

## WezTerm (Windows → WSL:arch)

WezTerm is a **Windows** app. `bootstrap.ps1` installs it and writes `%USERPROFILE%\.config\wezterm\wezterm.lua`:

- `default_domain = "WSL:arch"` (WezTerm names WSL domains `WSL:` + `wsl -l` name)
- `wsl_domains.default_cwd = "~"` so new windows/tabs open a Linux shell in the Linux home, not `C:\Users\...`
- Tokyo Night, JetBrainsMono Nerd Font, `hide_tab_bar_if_only_one_tab`

`theme` does not change Windows WezTerm. Edit `windows/wezterm.lua` and re-run `bootstrap.ps1` (or copy the file) if you want a different Windows scheme.

Do not install or launch Linux/WSLg `wezterm`.

## Themes

Default **Tokyo Night**. `theme` lists keys; `theme <name>` updates `.chezmoidata.toml` and runs `chezmoi apply` (Starship, Herdr, Neovim). Reload those apps if colors look stale.

## Toolchains

- mise globals: `node@lts`, `python@latest` (`mise install` after apply)
- direnv hook after mise; allow `.envrc` per repo
- Agents: Herdr, Cursor CLI (`agent`), Claude Code (`claude`), keep existing OpenCode2 / opencode-beta

## Out of scope

No extra Windows host automation beyond `bootstrap.ps1` (WSL + WezTerm) · no fish · no LazyVim · rootful Docker without `daemon.json` · atuin cloud sync off · herdr/Cursor/Claude versions not pinned (upstream scripts) · `install.sh` does not rewrite `/etc/wsl.conf` (Linux `bootstrap.sh` does, Day 0 only)
