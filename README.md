# Dotfiles (Arch Linux WSL)

Chezmoi-managed devops environment for **Arch in WSL**. Local git repo only for now — does **not** replace [github.com/nereumelo/dotfiles](https://github.com/nereumelo/dotfiles).

**Stack:** Bash + ble.sh + starship + mise + direnv · UX CLIs (zoxide, fzf, eza, atuin, bat, glow, fd, ripgrep, bottom, sd, jq, go-yq) · Windows WezTerm → WSL `arch` · Herdr · OpenCode 2 · Cursor CLI · Claude Code · Neovim · Docker · Bitwarden SSH + SSH commit signing · Tokyo Night theme

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
| `private_dot_config/opencode/tui.json.tmpl` | `~/.config/opencode/tui.json` |
| `private_dot_ssh/config.tmpl` | `~/.ssh/config` (`Include config.local`, then `IdentityFile` from `ssh-pub`) |
| `dot_local/bin/executable_theme` | `~/.local/bin/theme` |
| `dot_local/bin/executable_windows-open` | `~/.local/bin/windows-open` (`xdg-open` shim too) |

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
4. Writes `%USERPROFILE%\.config\wezterm\wezterm.lua` with `default_domain = "WSL:arch"` (Tokyo Night, JetBrainsMono Nerd Font, `hide_tab_bar_if_only_one_tab`, opacity `0.97`, `102×26`, new windows in `~` running herdr)
5. Opens distro `arch` as root and runs `bootstrap.sh` (same in-distro path as below)

Non-interactive Linux user creation: set `WSL_USER` / `WSL_PASSWORD` in that PowerShell session before running the script.

When it finishes, open **Windows WezTerm**. You should land in herdr in the Linux home directory (or login bash if herdr is not installed yet).

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

1. Unlock **Arch** Bitwarden → enable SSH agent → GitHub + VPS keys (sections below).
2. `./verify.sh`
3. Open a **new WezTerm window** (bash + docker group).
4. Per repo: add `.envrc` + `direnv allow` when needed; projects may also use `mise.toml`.

## Day N — edit dots

- Edit under `home/` or `chezmoi edit ~/.bashrc`
- Aliases/functions: `home/private_dot_config/bash/aliases.sh` / `functions.sh`, then `chezmoi apply`
- ble.sh (`~/.blerc`): case-insensitive TAB and auto-complete via `completion-ignore-case`
- Machine-only: `~/.config/bash/aliases.local.sh` (untracked)
- `chezmoi diff` / `chezmoi apply`
- `theme` / `theme tokyo-night` / `theme catppuccin`
- Re-run `./install.sh` is safe for packages; routine dots still go through chezmoi
- `./verify.sh` after big changes

bashrc **sources** aliases from `~/.config/bash/` — it does not embed them. Use `\ls` / `\cat` / `\vim` for the real binaries. `vim` is `nvim`.

## Privileges

Day 0: `bootstrap.ps1` as your **Windows** user, then `bootstrap.sh` as **root** inside `arch`.

Never: `sudo ./install.sh`, `sudo chezmoi`, `sudo paru`, `sudo mise`.

Sudo only for system pacman, system units, usermod, chsh. Linux bootstrap grants passwordless sudo only while `install.sh` runs, then restores password `wheel` sudo.

## Git / SSH / signing

- Personal identity from `.chezmoidata.toml`; work via `includeIf "gitdir:~/work/"` → `~/.config/git/config-work`
- `EDITOR` / `VISUAL` / `GIT_EDITOR=nvim` from bashrc (no `core.editor`)
- SSH commit signing with `~/.ssh/home-personal.pub`; agent via `SSH_AUTH_SOCK` → `~/.bitwarden-ssh-agent-notify.sock` (proxy) → `~/.bitwarden-ssh-agent.sock`
- `~/.ssh/config` is chezmoi-managed. It `Include`s gitignored `~/.ssh/config.local` (`HostName`, `User`, `IdentityAgent`, `IdentitiesOnly`) and then inlines `IdentityFile` from `~/.ssh/config.identity` (`ssh-pub`). HostName/User are not in git.
- `ssh-host-local <host> <hostname> <user>` writes that Host in `config.local` (`IdentityAgent ~/.bitwarden-ssh-agent-notify.sock` and `IdentitiesOnly yes` are always set). `ssh-pub <host> <key>` dumps the matching agent key to `~/.ssh/<key>.pub` and sets `IdentityFile` on `~/.ssh/config` — it errors if the Host is missing
- Without that `.pub` on disk, OpenSSH `IdentitiesOnly` ignores the agent (`identity file … type -1`, never `Offering public key`)
- Private keys stay in the **Arch** Bitwarden desktop SSH agent. There is no headless Bitwarden SSH daemon — the app must stay open and unlocked. `bw` CLI cannot sign SSH
- Site passwords (browser) are the Windows Bitwarden extension / same account; they are not this socket
- `cat` is aliased to `bat` — use `\cat` when you need the real binary
- Work in the Linux home (`wsl ~` / WezTerm `WSL:arch`). `wsl` from `C:\Users\…` lands on `/mnt/c` and Git/SSH there are the wrong tree

Bitwarden vault syncs via your account across Windows/Arch clients. Enable the SSH agent in the **Arch** desktop app. Do not bridge Windows `npiperelay` into WSL for this setup.

### Bitwarden agent (once)

1. Install/open **Arch** Bitwarden (pacman `bitwarden`), sign in, unlock
2. Settings → enable **SSH agent**
3. Confirm the socket and that keys appear after you import them:

```bash
echo "$SSH_AUTH_SOCK"    # ~/.bitwarden-ssh-agent-notify.sock when the proxy is up
ls -l ~/.bitwarden-ssh-agent.sock ~/.bitwarden-ssh-agent-notify.sock
ssh-add -l               # empty until SSH-key items exist and the vault is unlocked
```

`agent refused operation` means the desktop refused to sign: bring the Bitwarden window forward and **Allow**, or disable per-use confirmation in SSH-agent settings. WSLg often hides that prompt.

Bitwarden has no OS notification for SSH authorization. `bitwarden-ssh-notify` proxies the agent socket: a **sign** request writes BEL + OSC 777 into the waiting WezTerm pane (flash, beep, WezTerm notification) and tries to `xdotool` the Bitwarden window forward. `chezmoi apply` enables the systemd user unit. Copy `windows/wezterm.lua` for `visual_bell`. Test in WezTerm: `bitwarden-ssh-notify --test`.

### Hosts in `config.local`

One SSH alias per `Host` block. `<host>` is the alias you type (`ssh vps`, `git@github.com-acme`); `<hostname>` is the real name (`github.com`, `ssh.github.com`, an IP).

`install.sh` seeds `Host github.com` **only if it is missing**. If that block already has `HostName ssh.github.com` (or a GitHub Enterprise name), install leaves it. `IdentityAgent` and `IdentitiesOnly` are not function arguments. Re-running is a no-op: `Port` and other extra keys in `config.local` stay put.

```bash
ssh-host-local github.com github.com git          # skipped by install.sh if Host github.com exists
ssh-host-local vps YOUR_IP_OR_DNS YOUR_REMOTE_USER
ssh-host-local xpto example.com alice
```

Then bind a Bitwarden SSH-item comment to that Host:

```bash
ssh-pub github.com home-personal    # → ~/.ssh/home-personal.pub + IdentityFile in ~/.ssh/config
ssh-pub vps vps
ssh-pub xpto xpto                   # errors if Host xpto is missing
```

`ssh-pub` is idempotent when the `.pub` and `IdentityFile` already match. It writes `IdentityFile` via `~/.ssh/config.identity` and runs `chezmoi apply` so `~/.ssh/config` shows the key (and git signing templates for `home-personal` / `work`).

### Extra GitHub accounts / orgs

`github.com` and `github.com-acme` are different Host aliases. Both can use `HostName github.com` with different keys. Remotes must use the alias, not `git@github.com`, or SSH would pick the `Host github.com` key.

```bash
ssh-host-local github.com github.com git
ssh-pub github.com home-personal

ssh-host-local github.com-acme github.com git
ssh-pub github.com-acme acme

ssh-host-local github.com-work github.com git
ssh-pub github.com-work work

git clone git@github.com-acme:acme/repo.git
# git remote set-url origin git@github.com-acme:acme/repo.git
```

GitHub over 443 / Enterprise — change only `<hostname>` (and keep `Port` if you add it; `ssh-host-local` will not drop it):

```bash
ssh-host-local github.com ssh.github.com git
ssh-host-local ghe github.mycompany.com git
ssh-pub ghe work
```

### GitHub (`ssh git@github.com` + commit signing)

Private key only in Bitwarden (New item → **SSH key**: import or generate Ed25519). Name the item so the agent comment matches, e.g. `home-personal`.

```bash
ssh-host-local github.com github.com git   # skip if install.sh already seeded it
ssh-pub github.com home-personal
\cat ~/.ssh/home-personal.pub              # paste this line on GitHub
```

On GitHub → Settings → SSH and GPG keys, paste that same line twice:

1. **New SSH key** → type **Authentication Key** (`ssh -T` uses this)
2. **New SSH key** → type **Signing key** (commits; `gpg.format=ssh`)

A signing-only key is not enough for `ssh -T`.

```bash
ssh -T git@github.com
# success: Hi <user>! You've successfully authenticated, but GitHub does not provide shell access.
# exit status 1 is normal (no shell)
```

If it still fails, `ssh -o IdentitiesOnly=no -T git@github.com` tests the agent without the `.pub`. After `ssh-pub`, drop the `-o`.

Until the agent is unlocked: `git commit --no-gpg-sign`.

### VPS (`ssh vps`)

Use a **separate** Bitwarden SSH-key item (e.g. `vps`), not `home-personal`, unless that exact public key is also in the server `authorized_keys`.

```bash
ssh-host-local vps YOUR_IP_OR_DNS YOUR_REMOTE_USER
ssh-pub vps vps
```

Install the **same** public line on the server (`~/.ssh/authorized_keys` for that User), then:

```bash
ssh vps
```

Bitwarden must be unlocked; **Allow** if the agent prompts. `install.sh` may copy a legacy `vps_srv1938886.pub` → `vps.pub` when present. It will not overwrite an existing `Host vps` HostName/User. Delete leftover **private** key files from `~/.ssh/` after import.

## WezTerm (Windows → WSL:arch)

WezTerm is a **Windows** app. `bootstrap.ps1` installs it and writes `%USERPROFILE%\.config\wezterm\wezterm.lua`:

- `default_domain = "WSL:arch"` (WezTerm names WSL domains `WSL:` + `wsl -l` name)
- `wsl_domains.default_cwd = "~"` so new windows/tabs open in the Linux home, not `C:\Users\...`
- `wsl_domains.default_prog` starts **herdr** (`bash -lc` so `~/.local/bin` is on PATH). Herdr is not `exec`'d: **Ctrl+B** then **q** detaches to login bash (`herdr` reattaches). `exit` in that bash closes the pane. If herdr is missing, login bash. **Ctrl+Shift+L** launcher has a Bash entry for a normal shell
- **Ctrl+Backspace** deletes the previous word (sent as Ctrl+W). Ctrl+Delete already deletes the next word
- `visual_bell` + `notification_handling = AlwaysShow`: Bitwarden SSH sign-request proxy flashes the pane and shows a WezTerm notification (OSC 777)
- Tokyo Night, JetBrainsMono Nerd Font, `hide_tab_bar_if_only_one_tab`, `window_background_opacity = 0.97`, `initial_cols = 102`, `initial_rows = 26`. Neovim (tokyonight `transparent = true`) does not paint a solid `Normal` background, so that WezTerm opacity shows through.
- Clipboard: select copies; **Ctrl+C** copies when there is a selection (otherwise interrupt); **Ctrl+V** pastes
- Links: click or **Ctrl+click** opens the Windows default browser (`OpenLinkAtMouseCursor`). Copy-on-select left-click had replaced WezTerm's default, so Ctrl+click did nothing until this binding was restored

CLI tools (`claude`, `gh`, `xdg-open`) cannot see `cmd.exe` because `appendWindowsPath=false`. `~/.local/bin/windows-open` (and an `xdg-open` shim) call Windows PowerShell `Start-Process`. `BROWSER` / `GH_BROWSER` point at that script after a new shell (`chezmoi apply`).

Interactive bash helpers in `~/.config/bash/functions.sh`:

- `copy` — clipboard via **xclip** (X11) or **wl-copy** (Wayland). WSLg mirrors that to the Windows clipboard. Source encoding is detected (`file --mime-encoding`) and converted to UTF-8 **without a BOM** (a leading U+FEFF was the `clip.exe` UTF-16LE prefix). `copy readme.md` or `cat readme.md | copy` (`cat` is `bat -p`; `copy` reads stdin/`command cat`, not bat). Needs `DISPLAY`/`WAYLAND_DISPLAY` (WSLg).
- `open` — Windows Explorer (`explorer.exe` is not on PATH). `open` / `open .` is the current directory; `open ~/me/dotfiles` that folder. A file path uses `explorer /select,` so Explorer highlights it.

`theme` does not change Windows WezTerm. Edit `windows/wezterm.lua` and re-run `bootstrap.ps1` (or copy the file) if you want a different Windows scheme. After pulling WezTerm changes (opacity, herdr default, detach-to-bash, Ctrl+Backspace, visual_bell, clipboard, hyperlinks), copy `windows/wezterm.lua` over `%USERPROFILE%\.config\wezterm\wezterm.lua` and restart WezTerm.

Do not install or launch Linux/WSLg `wezterm`.

## Themes

Default **Tokyo Night**. `theme` lists keys; `theme <name>` updates `.chezmoidata.toml` and runs `chezmoi apply` (Starship, Herdr, Neovim, OpenCode TUI). Reload those apps if colors look stale. OpenCode reads the theme from `~/.config/opencode/tui.json` (not `opencode.json`).

## Toolchains

- mise globals: `node@lts`, `python@latest` (`mise install` after apply)
- direnv hook after mise; allow `.envrc` per repo
- Agents: OpenCode 2 (`opencode` via https://opencode.ai/v2/install into `~/.opencode/bin`, not extra/opencode 1.x) · Herdr, Cursor CLI (`agent`), Claude Code (`claude`)

## Out of scope

No extra Windows host automation beyond `bootstrap.ps1` (WSL + WezTerm) · no fish · no LazyVim · rootful Docker without `daemon.json` · atuin cloud sync off · herdr/Cursor/Claude versions not pinned (upstream scripts) · `install.sh` does not rewrite `/etc/wsl.conf` (Linux `bootstrap.sh` does, Day 0 only)
