# Funções auxiliares para formatação do console
function Write-Step ([string]$msg) { Write-Host "`n[i] $msg..." -ForegroundColor Yellow }
function Write-Ok ([string]$msg)   { Write-Host "[+] $msg" -ForegroundColor Green }
function Write-Warn ([string]$msg) { Write-Host "[!] $msg" -ForegroundColor DarkYellow }

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host " Iniciando Configuração Arch & Font       " -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan

# --- 1. Instalar Fonte via WinGet ---
Write-Step "Instalando JetBrainsMono Nerd Font"
try {
    # Usando o ID correto do pacote da comunidade no winget
    winget install --id DEVCOM.JetBrainsMonoNerdFont --source winget --accept-package-agreements --accept-source-agreements --silent
    Write-Ok "Fonte instalada."
} catch {
    Write-Warn "winget falhou para a fonte. Baixe manualmente em https://www.nerdfonts.com/font-downloads (JetBrainsMono)."
}

# --- 2. Instalar Arch Linux via WSL Nativo ---
Write-Step "Instalando Arch Linux no WSL"
try {
    # Instala a distribuição oficial registrada no repositório do WSL
    wsl --install archlinux
    Write-Ok "Arch Linux instalado com sucesso."
    Write-Warn "Caso o terminal não tenha aberto automaticamente, reinicie a sessão ou execute 'wsl -d archlinux'."
} catch {
    Write-Warn "Falha ao executar 'wsl --install archlinux'. Verifique se o WSL está atualizado."
}

Write-Host "`n==========================================" -ForegroundColor Green
Write-Host " Processo finalizado!                      " -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Green