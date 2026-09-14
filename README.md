# Dotfiles (Arch Linux WSL)

Chezmoi-managed devops environment for **Arch in WSL**. Local git repo only for now — does **not** replace [github.com/nereumelo/dotfiles](https://github.com/nereumelo/dotfiles).

**Stack:** Bash + ble.sh + starship + mise + direnv · UX CLIs (zoxide, fzf, eza, atuin, bat, glow, fd, ripgrep, bottom, sd, jq, go-yq) · WezTerm · Herdr · OpenCode2 · Cursor CLI · Claude Code · Neovim · Docker · Bitwarden SSH + SSH commit signing · Tokyo Night theme

## Repository layout

```
dotfiles/
├── bootstrap.sh               # root first-boot (curl | bash)
├── install.sh / verify.sh     # package + machine bootstrap as your user
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
| `private_dot_config/wezterm/` | `~/.config/wezterm/` |
| `private_dot_ssh/config.tmpl` | `~/.ssh/config` |
| `dot_local/bin/executable_theme` | `~/.local/bin/theme` |
| `dot_local/share/applications/org.wezfurlong.wezterm.desktop` | `~/.local/share/applications/org.wezfurlong.wezterm.desktop` |

`install.sh` owns packages. Chezmoi never installs packages.

## Day 0 — fresh Arch, still root

Official Arch WSL lands you as **root** with a minimal image (often no `curl` / `sudo` / `git`). One command:

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
4. Runs `./install.sh` as that user (packages, paru, chezmoi, tools)

When it finishes, from **Windows**: `wsl --shutdown`, then reopen the distro — you should land as the new user.

Already the target user with the repo cloned? Skip bootstrap:

```bash
./install.sh
```

Sudo is prompted for pacman / systemctl / usermod / chsh only. Env flags: `SKIP_DOCKER=1`, `SKIP_LAZYDOCKER=1`. Root-only machine setup: `DOTFILES_SKIP_INSTALL=1`.

Then:

1. Unlock **Arch** Bitwarden → enable SSH agent → import keys → fill `~/.ssh/config.local` for VPS (checklist below).
2. `./verify.sh`
3. Open a **new login shell** (bash + docker group).
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

Day 0 is the exception: `curl …/bootstrap.sh | bash` as **root**.

Never: `sudo ./install.sh`, `sudo chezmoi`, `sudo paru`, `sudo mise`.

Sudo only for system pacman, system units, usermod, chsh. Bootstrap grants passwordless sudo only while `install.sh` runs, then restores password `wheel` sudo.

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

## WezTerm (WSLg)

Arch `wezterm` on WSLg does not use Wayland. `enable_wayland = false` plus `window_decorations = "TITLE | RESIZE"` keep a normal X11/Win32 frame (the Start menu shortcut otherwise stays on Wayland and becomes a borderless panel). `~/.local/share/applications/org.wezfurlong.wezterm.desktop` launches with `WAYLAND_DISPLAY=` and `LIBGL_ALWAYS_SOFTWARE=1` so **Start → WezTerm (arch)** matches a working CLI. `vulkan-icd-loader` and `vulkan-swrast` are in `packages/pacman.txt`. After apply: `wsl --shutdown` once if the old shortcut is cached.

Do not set nightly-only keys such as `mux_enable_ssh_agent` on extra/wezterm — unknown `config_builder()` fields abort startup.

## Themes

Default **Tokyo Night**. `theme` lists keys; `theme <name>` updates `.chezmoidata.toml` and runs `chezmoi apply` (WezTerm, Starship, Herdr, Neovim). Reload GUI apps if colors look stale.

## Toolchains

- mise globals: `node@lts`, `python@latest` (`mise install` after apply)
- direnv hook after mise; allow `.envrc` per repo
- Agents: Herdr, Cursor CLI (`agent`), Claude Code (`claude`), keep existing OpenCode2 / opencode-beta

## Out of scope

No Windows host automation · no fish · no LazyVim · rootful Docker without `daemon.json` · atuin cloud sync off · herdr/Cursor/Claude versions not pinned (upstream scripts) · `install.sh` does not rewrite `/etc/wsl.conf` (bootstrap does, Day 0 only)
