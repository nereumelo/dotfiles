#!/bin/bash
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

pacman-key --init
pacman-key --populate archlinux
pacman -Sy archlinux-keyring --noconfirm
pacman -Syu --noconfirm
BASE_PKGS=(
    base-devel git sudo fish openssh gnupg keychain which
    docker docker-compose
    curl wget unzip zip less man-db
    vi neovim ripgrep fd fzf bat eza jq
    zoxide git-delta btop uv
)
pacman -S --needed --noconfirm "${BASE_PKGS[@]}"

useradd -m -G wheel -s /usr/bin/fish "${user}"
echo "${user}:${password}" | chpasswd
sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers

# setup locale
sed -i 's/^#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf

cat <<EOF > /etc/wsl.conf
[boot]
systemd=true

[user]
default=${user}

[interop]
enabled=true
appendWindowsPath=true
EOF
