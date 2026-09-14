# bootstrap.ps1 — Day 0 from Windows PowerShell / Windows Terminal (not inside Linux).
#
#   irm https://raw.githubusercontent.com/nereumelo/dotfiles/main/bootstrap.ps1 | iex
#   powershell -ExecutionPolicy Bypass -File .\bootstrap.ps1
#
# Optional env: WSL_USER, WSL_PASSWORD, DOTFILES_REPO, DOTFILES_REF, SKIP_DOCKER,
#               SKIP_LAZYDOCKER, DOTFILES_SKIP_INSTALL
# WezTerm is a Windows app. This script does not install Linux wezterm.

$ErrorActionPreference = 'Stop'
$env:WSL_UTF8 = '1'

$DistroName = 'arch'
$OfficialId = 'archlinux'
$WingetWezTerm = 'wez.wezterm'
$WingetNerdFont = 'DEVCOM.JetBrainsMonoNerdFont'
$DotfilesRef = if ($env:DOTFILES_REF) { $env:DOTFILES_REF } else { 'main' }
$RawBase = "https://raw.githubusercontent.com/nereumelo/dotfiles/$DotfilesRef"
$WeztermLuaDest = Join-Path $env:USERPROFILE '.config\wezterm\wezterm.lua'

$ScriptRoot = $PSScriptRoot
if (-not $ScriptRoot -and $PSCommandPath) {
  $ScriptRoot = Split-Path -Parent $PSCommandPath
}

function Write-Log([string]$Message) {
  Write-Host "==> $Message"
}

function Write-Warn([string]$Message) {
  Write-Host "warning: $Message" -ForegroundColor Yellow
}

function Test-IsAdmin {
  $id = [Security.Principal.WindowsIdentity]::GetCurrent()
  $p = New-Object Security.Principal.WindowsPrincipal($id)
  return $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Get-WslDistroNames {
  $prev = $env:WSL_UTF8
  $env:WSL_UTF8 = '1'
  try {
    $out = & wsl.exe --list --quiet 2>$null
    if ($LASTEXITCODE -ne 0 -and -not $out) { return @() }
    return @(
      $out |
        ForEach-Object { ($_ -as [string]).Trim() } |
        Where-Object { $_ -and $_ -notmatch '^(Windows Subsystem|The requested|Copyright)' }
    )
  } finally {
    if ($null -eq $prev) { Remove-Item Env:WSL_UTF8 -ErrorAction SilentlyContinue } else { $env:WSL_UTF8 = $prev }
  }
}

function Test-WslDistro([string]$Name) {
  return [bool](Get-WslDistroNames | Where-Object { $_ -ieq $Name })
}

function Assert-Wsl2 {
  if (-not (Get-Command wsl.exe -ErrorAction SilentlyContinue)) {
    Write-Log 'WSL is not installed. Installing WSL2 (no default distro)...'
    if (-not (Test-IsAdmin)) {
      throw 'Install WSL from an elevated PowerShell: wsl --install --no-distribution   then reboot and re-run this script.'
    }
    & wsl.exe --install --no-distribution
    throw 'WSL was installed. Reboot Windows, then re-run bootstrap.ps1.'
  }

  try {
    & wsl.exe --status | Out-Null
  } catch {
    throw 'WSL is present but not ready. Reboot Windows, then re-run bootstrap.ps1.'
  }

  & wsl.exe --set-default-version 2 2>$null | Out-Null
}

function Install-ArchDistro {
  if (Test-WslDistro $DistroName) {
    Write-Log "WSL distro '$DistroName' already exists (reusing)"
    return
  }

  foreach ($old in @('archlinux', 'ArchLinux', 'Arch')) {
    if ($old -ieq $DistroName) { continue }
    if (Test-WslDistro $old) {
      Write-Log "Renaming WSL distro '$old' -> '$DistroName'"
      & wsl.exe --terminate $old 2>$null | Out-Null
      & wsl.exe --manage $old --set-name $DistroName
      if (Test-WslDistro $DistroName) { return }
      throw "Failed to rename '$old' to '$DistroName'. Try: wsl --manage $old --set-name $DistroName"
    }
  }

  Write-Log "Installing official Arch Linux WSL as '$DistroName' (not $OfficialId)"
  $installAttempts = @(
    { & wsl.exe --install $OfficialId --name $DistroName --no-launch },
    { & wsl.exe --install --distribution $OfficialId --name $DistroName --no-launch },
    { & wsl.exe --install -d $OfficialId --name $DistroName --no-launch }
  )
  foreach ($attempt in $installAttempts) {
    if (Test-WslDistro $DistroName) { break }
    try { & $attempt } catch { Write-Warn $_.Exception.Message }
  }

  if (-not (Test-WslDistro $DistroName) -and (Test-WslDistro $OfficialId)) {
    Write-Log "Install used default name '$OfficialId'; renaming to '$DistroName'"
    & wsl.exe --terminate $OfficialId 2>$null | Out-Null
    & wsl.exe --manage $OfficialId --set-name $DistroName
  }

  if (-not (Test-WslDistro $DistroName)) {
    throw @"
Could not create WSL distro named '$DistroName'.
Install Arch (wsl --install $OfficialId), then: wsl --manage $OfficialId --set-name $DistroName
Re-run this script after `wsl -l` shows: $DistroName
"@
  }
}

function Install-WingetPackage([string]$Id, [string]$What) {
  if (-not (Get-Command winget.exe -ErrorAction SilentlyContinue)) {
    Write-Warn "winget not found; install $What manually"
    return
  }
  Write-Log "Ensuring $What ($Id)"
  & winget.exe install --exact --id $Id --accept-package-agreements --accept-source-agreements
  if ($LASTEXITCODE -ne 0 -and $LASTEXITCODE -ne -1978335189) {
    # -1978335189 = already installed (varies by winget); treat other codes as warning
    Write-Warn "winget exit $LASTEXITCODE for $Id (continuing if the app is present)"
  }
}

function Get-WeztermLuaText {
  $local = if ($ScriptRoot) { Join-Path $ScriptRoot 'windows\wezterm.lua' } else { $null }
  if ($local -and (Test-Path -LiteralPath $local)) {
    return Get-Content -LiteralPath $local -Raw -Encoding UTF8
  }
  Write-Log "Fetching wezterm.lua from $RawBase/windows/wezterm.lua"
  return (Invoke-WebRequest -UseBasicParsing -Uri "$RawBase/windows/wezterm.lua").Content
}

function Write-WeztermConfig {
  $dir = Split-Path -Parent $WeztermLuaDest
  New-Item -ItemType Directory -Force -Path $dir | Out-Null
  $lua = Get-WeztermLuaText
  if (-not $lua -or $lua -notmatch 'WSL:arch') {
    throw 'Windows WezTerm config missing WSL:arch domain'
  }
  Write-Log "Writing $WeztermLuaDest (default_domain = `"WSL:arch`", cwd ~)"
  $utf8NoBom = New-Object System.Text.UTF8Encoding $false
  [System.IO.File]::WriteAllText($WeztermLuaDest, $lua, $utf8NoBom)
}

function Get-LinuxEnvPrefix {
  $names = @(
    'WSL_USER', 'WSL_PASSWORD', 'DOTFILES_USER', 'DOTFILES_PASSWORD',
    'DOTFILES_REPO', 'DOTFILES_REF', 'DOTFILES_DIR',
    'SKIP_DOCKER', 'SKIP_LAZYDOCKER', 'DOTFILES_SKIP_INSTALL'
  )
  $parts = New-Object System.Collections.Generic.List[string]
  foreach ($n in $names) {
    $v = [Environment]::GetEnvironmentVariable($n)
    if ([string]::IsNullOrEmpty($v)) { continue }
    $escaped = $v.Replace("'", "'\''")
    $parts.Add("export $n='$escaped'")
  }
  if ($parts.Count -eq 0) { return '' }
  return ($parts -join '; ') + '; '
}

function Invoke-LinuxBootstrap {
  Write-Log "Running Linux bootstrap.sh as root in distro '$DistroName' (no Linux WezTerm)"
  $envPrefix = Get-LinuxEnvPrefix
  if ($envPrefix -notmatch 'export DOTFILES_REF=') {
    $envPrefix = ("export DOTFILES_REF='{0}'; " -f $DotfilesRef) + $envPrefix
  }

  $localSh = if ($ScriptRoot) { Join-Path $ScriptRoot 'bootstrap.sh' } else { $null }
  if ($localSh -and (Test-Path -LiteralPath $localSh)) {
    $winPath = (Resolve-Path -LiteralPath $ScriptRoot).Path
    $wslPath = (& wsl.exe -d $DistroName -u root -- wslpath -a $winPath | Out-String).Trim()
    if (-not $wslPath) { throw "wslpath failed for $winPath" }
    $cmd = "${envPrefix}bash `"$wslPath/bootstrap.sh`""
    Write-Log "Using local $localSh"
  } else {
    $cmd = @"
${envPrefix}set -euo pipefail
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
if ! command -v curl >/dev/null 2>&1; then
  pacman-key --init
  pacman-key --populate archlinux
  pacman -Syu --noconfirm archlinux-keyring curl
fi
curl -fsSL $RawBase/bootstrap.sh | bash
"@
    Write-Log "Using $RawBase/bootstrap.sh"
  }

  & wsl.exe -d $DistroName -u root -- bash -lc $cmd
  if ($LASTEXITCODE -ne 0) {
    throw "Linux bootstrap failed (exit $LASTEXITCODE)"
  }
}

Assert-Wsl2
Install-ArchDistro
& wsl.exe --set-default $DistroName 2>$null | Out-Null

Install-WingetPackage $WingetWezTerm 'WezTerm (Windows)'
Install-WingetPackage $WingetNerdFont 'JetBrainsMono Nerd Font (Windows)'
Write-WeztermConfig
Invoke-LinuxBootstrap

Write-Log 'Shutting down WSL so [user] default and systemd from wsl.conf apply'
& wsl.exe --shutdown

Write-Host @"

--------------------------------------------------------------------
Windows bootstrap finished.

Distro:   $DistroName   (wsl -l)
WezTerm:  Windows app, default_domain = WSL:arch, new windows start in ~
Config:   $WeztermLuaDest

Open Windows WezTerm. New windows use domain WSL:arch and start in Linux ~.

If Linux bootstrap asked you to reboot/shutdown already, you are done.
--------------------------------------------------------------------
"@
