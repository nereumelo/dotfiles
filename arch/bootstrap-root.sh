#!/bin/bash
set -euo pipefail

read -r -p "Username: " user
while [[ -z "${user}" ]]; do
  read -r -p "Username (required): " user
done

while true; do
  read -r -s -p "Password: " password
  echo
  read -r -s -p "Confirm password: " password_confirm
  echo
  if [[ -z "${password}" ]]; then
    echo "Password cannot be empty." >&2
  elif [[ "${password}" != "${password_confirm}" ]]; then
    echo "Passwords do not match. Try again." >&2
  else
    break
  fi
done

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
