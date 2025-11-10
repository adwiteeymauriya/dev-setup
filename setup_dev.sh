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

# Validate mode
if [[ -n "$MODE" && "$MODE" != "--init" && "$MODE" != "--attach" ]]; then
  fail "Invalid mode: $MODE. Use --init (fresh setup) or --attach (reattach existing)"
fi

# Set default mode if not provided
if [[ -z "$MODE" ]]; then
  log "No mode specified. Use --init for fresh setup or --attach for existing setup"
  fail "Mode required: --init or --attach"
fi

# ========= ROOT-LEVEL SETUP =========

log "Installing base packages..."
apt-get update -y
apt-get install -y sudo vim curl wget git unzip zip zsh ca-certificates uidmap

# ========= VOLUME & MOUNT SETUP =========
log "Setting up persistent volume storage..."

if [[ ! -b "$DEVICE" ]]; then
  fail "Volume device not found: $DEVICE"
fi

# Only format in --init mode
if [[ "$MODE" == "--init" ]]; then
  if ! blkid "$DEVICE" >/dev/null 2>&1; then
    log "Formatting volume as ext4..."
    mkfs.ext4 -F "$DEVICE"
  else
    log "Volume already has filesystem, skipping format"
  fi
fi

# Mount home directory
log "Mounting home directory: $HOME_DIR"
mkdir -p "$HOME_DIR"
sed -i "\|$DEVICE $HOME_DIR|d" /etc/fstab
echo "$DEVICE $HOME_DIR ext4 discard,defaults 0 2" >> /etc/fstab
mountpoint -q "$HOME_DIR" || mount "$HOME_DIR"

# Setup /nix bind mount
log "Setting up persistent /nix storage..."
mkdir -p "$NIX_DIR"
mkdir -p /nix
sed -i '\| /nix |d' /etc/fstab
echo "$NIX_DIR  /nix   none  bind  0 0" >> /etc/fstab
mountpoint -q /nix || mount /nix

# ========= USER SETUP =========
log "Setting up user: $USERNAME"

if ! id -u "$USERNAME" >/dev/null 2>&1; then
  log "Creating user $USERNAME"
  groupadd -g "$USER_GID" "$USERNAME" 2>/dev/null || true
  useradd -m -d "$HOME_DIR" -s "$ZSH_BIN" -u "$USER_UID" -g "$USER_GID" "$USERNAME"
else
  log "User $USERNAME exists, updating settings"
  usermod -d "$HOME_DIR" -s "$ZSH_BIN" "$USERNAME" || true
fi

# Set ownership
chown -R "$USERNAME:$USERNAME" "$HOME_DIR"
chown -R "$USERNAME:$USERNAME" "$NIX_DIR"
chown -R "$USERNAME:$USERNAME" /nix

# Setup SSH keys (only in --init mode or if not already present)
if [[ "$MODE" == "--init" ]] || [[ ! -d "$HOME_DIR/.ssh" ]]; then
  if [[ -d /root/.ssh ]]; then
    log "Copying SSH keys from root to user"
    mkdir -p "$HOME_DIR/.ssh"
    cp -r /root/.ssh/* "$HOME_DIR/.ssh/" 2>/dev/null || true
    chown -R "$USERNAME:$USERNAME" "$HOME_DIR/.ssh"
    chmod 700 "$HOME_DIR/.ssh"
    find "$HOME_DIR/.ssh" -type f -exec chmod 600 {} \;
  fi
fi

# Configure passwordless sudo
log "Configuring passwordless sudo..."
echo "$USERNAME ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/"$USERNAME"
chmod 440 /etc/sudoers.d/"$USERNAME"

# ========= DOCKER INSTALLATION (ROOT) =========
if ! command -v docker >/dev/null 2>&1; then
  log "Installing Docker..."
  curl -fsSL https://get.docker.com -o /tmp/get-docker.sh
  sh /tmp/get-docker.sh
else
  log "Docker already installed, skipping"
fi

# ========= USER-LEVEL SETUP (CONSOLIDATED) =========
log "Running user-level development tool setup..."

# Determine if we should skip installations (attach mode with existing tools)
SKIP_INSTALL=false
if [[ "$MODE" == "--attach" ]] && [[ -f "$HOME_DIR/.dev_tools_installed" ]]; then
  log "Attach mode: development tools already installed, skipping"
  SKIP_INSTALL=true
fi

if [[ "$SKIP_INSTALL" == false ]]; then
  log "Installing development tools as user $USERNAME..."

  # Run all user-level installations in a single consolidated block
  sudo -u "$USERNAME" HOME="$HOME_DIR" bash <<'EOF'
set -euo pipefail

echo "[USER] Starting development tools installation..."

# ========= NIX =========
if [[ ! -f "$HOME/.nix-profile/etc/profile.d/nix.sh" ]]; then
  echo "[USER] Installing Nix..."
  curl -L https://nixos.org/nix/install -o "$HOME/install-nix.sh"
  sh "$HOME/install-nix.sh" --no-daemon

  # Add Nix to shell config
  if ! grep -q "nix.sh" "$HOME/.zshrc" 2>/dev/null; then
    echo 'source $HOME/.nix-profile/etc/profile.d/nix.sh' >> "$HOME/.zshrc"
  fi
else
  echo "[USER] Nix already installed, skipping"
fi

# ========= DEVBOX =========
if ! command -v devbox >/dev/null 2>&1; then
  echo "[USER] Installing Devbox..."
  curl -fsSL https://get.jetpack.io/devbox | bash

  # Ensure .local/bin is in PATH
  if ! grep -q ".local/bin" "$HOME/.zshrc" 2>/dev/null; then
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.zshrc"
  fi
else
  echo "[USER] Devbox already installed, skipping"
fi

# Mark tools as installed
touch "$HOME/.dev_tools_installed"
echo "[USER] Development tools installation complete"
EOF

  log "User-level setup complete"
else
  log "Skipped development tools installation (already present)"
fi

# ========= COMPLETION =========
log "========================================="
log "Setup complete!"
log "========================================="
log "Mode: $MODE"
log "User: $USERNAME"
log "Home: $HOME_DIR (on persistent volume)"
log "/nix: Bound to persistent volume"
log ""
log "Installed tools:"
log "  - Nix (single-user mode)"
log "  - Devbox"
log "  - Docker"
log ""
log "Switch to user: su - $USERNAME"
log "========================================="
