#!/usr/bin/env bash
set -euo pipefail

if [[ ! -r /dev/tty ]]; then
  echo "No controlling terminal. Use: WSL_USER=... WSL_PASSWORD=... curl ... | bash" >&2
  exit 1
fi

read_tty() {
  local var=$1 prompt=$2
  IFS= read -r -p "${prompt}" "${var}" </dev/tty
}

read_tty_secret() {
  local var=$1 prompt=$2
  IFS= read -r -s -p "${prompt}" "${var}" </dev/tty
  echo >&2
}

user="${WSL_USER:-}"
password="${WSL_PASSWORD:-}"

if [[ -z "${user}" ]]; then
  read_tty user "Username: "
  while [[ -z "${user}" ]]; do
    read_tty user "Username (required): "
  done
fi

if [[ -z "${password}" ]]; then
  while true; do
    read_tty_secret password "Password: "
    read_tty_secret password_confirm "Confirm password: "
    if [[ -z "${password}" ]]; then
      echo "Password cannot be empty." >&2
    elif [[ "${password}" != "${password_confirm}" ]]; then
      echo "Passwords do not match. Try again." >&2
    else
      break
    fi
  done
fi


BASE_PKGS=(
    base-devel git sudo openssh gnupg keychain which
    docker docker-compose
    curl wget unzip zip less man-db
    vi neovim ripgrep fd fzf bat eza jq
    zoxide git-delta btop uv
)

# 1. Ajuste e atualização do keyring
rm -rf /etc/pacman.d/gnupg
pacman-key --init
pacman-key --populate archlinux
pacman -Syu --noconfirm archlinux-keyring
pacman -S --needed --noconfirm "${BASE_PKGS[@]}"

# 2. Criação do Usuário (Idempotente)
if id -u "${user}" >/dev/null 2>&1; then
  echo "User '${user}' already exists. Updating groups and shell..."
  usermod -aG wheel,docker -s /bin/bash "${user}"
else
  useradd -m -G wheel,docker -s /bin/bash "${user}"
fi

echo "${user}:${password}" | chpasswd

# 3. Permissão de Sudo Segura via drop-in (/etc/sudoers.d/)
echo "%wheel ALL=(ALL:ALL) ALL" > "/etc/sudoers.d/10-wheel"
chmod 0440 "/etc/sudoers.d/10-wheel"

# 4. Habilitar o Docker para o systemd do WSL
systemctl enable docker.service

# 5. Configuração de Locales
sed -i 's/^#\?\s*en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf

# 6. Configuração do WSL (/etc/wsl.conf)
cat <<EOF > /etc/wsl.conf
[boot]
systemd=true

[user]
default=${user}

[interop]
enabled=true
appendWindowsPath=true
EOF

echo "Setup completed successfully! Please restart WSL (wsl.exe --shutdown)."
