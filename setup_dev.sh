#!/usr/bin/env bash
set -euo pipefail

# ========= CONFIG =========
USERNAME="qwe"
USER_UID=1000
USER_GID=1000
DEVICE="/dev/disk/by-id/scsi-0HC_Volume_103912881"
HOME_DIR="/home/${USERNAME}"
NIX_DIR="${HOME_DIR}/nix"
ZSH_BIN="/usr/bin/zsh"
MODE="${1:-}"   # --init or --attach

fail() { echo -e "\033[1;31m[ERROR]\033[0m $1"; exit 1; }
log()  { echo -e "\033[1;32m[+]\033[0m $1"; }

# ========= BASIC PACKAGES =========
log "Installing base packages..."
apt-get update -y
apt-get install -y sudo vim curl wget git unzip zip zsh ca-certificates uidmap

# ========= MOUNT HOME ON VOLUME =========
log "Ensuring mountpoint exists: $HOME_DIR"
mkdir -p "$HOME_DIR"

if [[ ! -b "$DEVICE" ]]; then fail "Volume device not found: $DEVICE"; fi

if [[ "$MODE" == "--init" ]]; then
  if ! blkid "$DEVICE" >/dev/null 2>&1; then
    log "Formatting volume as ext4..."
    mkfs.ext4 -F "$DEVICE"
  else
    log "Volume already formatted. Skipping."
  fi
else
  log "--attach mode: skipping format."
fi

log "Adding home mount to /etc/fstab and mounting..."
sed -i "\|$DEVICE $HOME_DIR|d" /etc/fstab
echo "$DEVICE $HOME_DIR ext4 discard,defaults 0 2" >> /etc/fstab
mountpoint -q "$HOME_DIR" || mount "$HOME_DIR"

# ========= USER CREATION =========
log "Ensuring user exists..."
if ! id -u $USERNAME >/dev/null 2>&1; then
  groupadd -g $USER_GID $USERNAME || true
  useradd -m -d "$HOME_DIR" -s "$ZSH_BIN" -u $USER_UID -g $USER_GID $USERNAME
else
  usermod -d "$HOME_DIR" -s "$ZSH_BIN" $USERNAME || true
fi
chown -R $USERNAME:$USERNAME "$HOME_DIR"

# ========= SSH KEY COPY FROM ROOT TO USER =========
log "Copying SSH keys from root to user (if present)..."
if [[ -d /root/.ssh ]]; then
  if [[ ! -d "$HOME_DIR/.ssh" ]]; then
    mkdir -p "$HOME_DIR/.ssh"
    cp -r /root/.ssh/* "$HOME_DIR/.ssh/"
    chown -R $USERNAME:$USERNAME "$HOME_DIR/.ssh"
    chmod 700 "$HOME_DIR/.ssh"
    chmod 600 "$HOME_DIR/.ssh"/*
  fi
else
  log "No SSH keys found in /root/.ssh, skipping."
fi


log "Passwordless sudo..."
echo "$USERNAME ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/$USERNAME
chmod 440 /etc/sudoers.d/$USERNAME

# ========= /nix ON PERSISTENT VOLUME =========
log "Configuring persistent /nix storage..."

mkdir -p "$NIX_DIR"
chown -R $USERNAME:$USERNAME "$NIX_DIR"

mkdir -p /nix

sed -i '\| /nix |d' /etc/fstab
echo "$NIX_DIR  /nix   none  bind  0 0" >> /etc/fstab

mountpoint -q /nix || mount /nix
chown -R $USERNAME:$USERNAME /nix

# ========= SIMPLE NIX INSTALL (NO DAEMON) =========
log "Installing Nix (normal, simple)..."

# Download installer to persistent home
sudo -u $USERNAME HOME="$HOME_DIR" bash -c '
  curl -L https://nixos.org/nix/install -o "$HOME/install-nix.sh"
'

# Run installer normally (no-daemon)
sudo -u $USERNAME HOME="$HOME_DIR" bash -c '
  sh "$HOME/install-nix.sh" --no-daemon
'

# Ensure nix loads in shell
sudo -u $USERNAME HOME="$HOME_DIR" bash -c '
  if ! grep -q "nix.sh" "$HOME/.zshrc" 2>/dev/null; then
    echo "source \$HOME/.nix-profile/etc/profile.d/nix.sh" >> "$HOME/.zshrc"
  fi
'

# ========= NODE 22 (NVM) =========
log "Installing NVM + Node 22..."
if [[ ! -d "$HOME_DIR/.nvm" ]]; then
  sudo -u $USERNAME HOME="$HOME_DIR" bash -c \
    'curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash'
fi

sudo -u $USERNAME HOME="$HOME_DIR" bash -lc '
  export NVM_DIR="$HOME/.nvm"
  . "$NVM_DIR/nvm.sh"
  nvm install 22
  nvm alias default 22
'

# ========= uv =========
log "Installing uv..."
sudo -u $USERNAME HOME="$HOME_DIR" bash -lc \
  'curl -LsSf https://astral.sh/uv/install.sh | sh && echo "export PATH=\$HOME/.local/bin:\$PATH" >> ~/.zshrc'

# ========= Devbox (LOCAL) =========
log "Installing Devbox locally..."
sudo -u $USERNAME HOME="$HOME_DIR" bash -lc '
if ! command -v devbox >/dev/null 2>&1; then
  curl -fsSL https://get.jetpack.io/devbox | bash
fi
echo "export PATH=\"\$HOME/.local/bin:\$PATH\"" >> ~/.zshrc
'

# ========= Docker (normal root install) =========
log "Installing Docker..."
curl -fsSL https://get.docker.com -o /tmp/get-docker.sh
sh /tmp/get-docker.sh
# sudo -u $USERNAME HOME="$HOME_DIR" bash -lc '
# dockerd-rootless-setuptool.sh install --force 
# '

# ========= DONE =========
log "All complete."
echo "Home mounted on volume"
echo "/nix bound to volume = persistent"
echo "Nix installed normally"
echo "Devbox ready"
echo "Docker installed"
echo "User $USERNAME fully configured"
