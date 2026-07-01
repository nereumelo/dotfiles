# dotfiles

Ambiente de desenvolvimento reproduzivel para **Arch Linux no WSL** 

Publicado em [github.com/nereumelo/dotfiles](https://github.com/nereumelo/dotfiles).

## Setup (maquina nova)

### 1. Windows (PowerShell)

```powershell
irm https://raw.githubusercontent.com/nereumelo/dotfiles/main/windows/install.ps1 | iex
```

Instala Arch WSL, Alacritty, JetBrainsMono Nerd Font, e aplica `windows/alacritty.toml`.

### 2. Arch, como root (primeiro boot)

Dentro do Alacritty, logado como root:

```bash
curl -fsSL https://raw.githubusercontent.com/nereumelo/dotfiles/main/arch/bootstrap-root.sh | bash
```

Prepara pacman, pacotes base, usuario (`wheel` + `docker`, shell `fish`), e `/etc/wsl.conf`.

No **Windows**: `wsl --shutdown`. Reabra o Alacritty — voce cai como o usuario normal, no fish.

### 3. Arch, como usuario normal

```bash
curl -fsSL https://raw.githubusercontent.com/nereumelo/dotfiles/main/arch/bootstrap.sh | bash
```

Instala a stack completa (paru, fish/tide, tmux, mise, Docker, LazyVim), pergunta se quer configurar segredos, e roda a verificacao.

> `curl | bash` ocupa o stdin com o corpo do script; os prompts leem de `/dev/tty`. Para revisar antes: `curl -fsSL ... -o bootstrap.sh && less bootstrap.sh && bash bootstrap.sh`.

### Variaveis opcionais (passo 3)

| Variavel | Efeito |
|----------|--------|
| `SKIP_DOCKER=1` | Pula Docker e lazydocker |
| `SKIP_SECRETS=1` | Pula o prompt de git/SSH/GPG |
| `SKIP_VERIFY=1` | Pula `arch/verify.sh` no final |

## Re-convergir (maquina existente)

```bash
cd ~/dotfiles && git pull --ff-only
bash arch/bootstrap-user.sh
```

Idempotente — pode rodar de novo a qualquer momento.

## Estrutura do repo

```
bootstrap.sh                 wrapper curl | bash -> arch/bootstrap-user.sh
windows/install.ps1          host Windows: Arch + Alacritty + fonte
windows/alacritty.toml       tema Tokyo Night, shell -> wsl archlinux
arch/lib/common.sh           helpers compartilhados
arch/bootstrap-root.sh       root, 1o boot: pacman, usuario, wsl.conf
arch/bootstrap-user.sh       usuario: stack completa + secrets + verify
arch/secrets.sh              git identity / SSH / GPG, interativo
arch/verify.sh               checklist de verificacao
arch/00-bootstrap-root.sh    wrapper (URL antiga)
arch/01-setup-user.sh        wrapper (URL antiga, so setup)
config/wsl.conf              fonte do /etc/wsl.conf
config/git/config            git base (delta, nvim, etc.)
config/fish/                 shell (mise, zoxide, tmux auto-attach)
config/tmux/tmux.conf        tmux + tpm plugins
config/mise/config.toml      versoes globais mise
config/nvim/                 overlay LazyVim (Tokyo Night)
```

## Design notes

<details>
<summary>Por que este repo e publico</summary>

Um `git clone` de repo privado exige credenciais ja configuradas — impossivel logo depois de um `wsl --install`. Este repo nao tem segredos (bloqueado por `.gitignore`) e pode ser clonado sem autenticacao.

</details>

<details>
<summary>Decisoes de arquitetura</summary>

- **Arch Linux** (imagem oficial WSL) em vez de Ubuntu.
- **mise** unico gerenciador poliglota para node/python/go/rust/java. Global = latest/LTS; `mise.toml` por projeto tem prioridade.
- **Node**: `npm`. **Python**: `uv` para venvs (mise fornece o interpretador).
- **tmux** (nao zellij): prefix `Ctrl+b`, mouse ligado, plugins via tpm.
- **Alacritty** (nao kitty): roda nativo no Windows com GPU; kitty exigiria WSLg.
- **LazyVim** com Tokyo Night como editor de terminal, alem do Cursor.
- **Segredos**: `arch/secrets.sh` e 100% interativo. Nada versionado.

</details>