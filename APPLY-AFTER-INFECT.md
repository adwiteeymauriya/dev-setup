# Applying Your Configuration After nixos-infect

After running `nixos-infect-custom`, you'll have a minimal NixOS installation with auto-generated configuration. Here's how to apply your full configuration.

## What nixos-infect Creates

```
/etc/nixos/
├── configuration.nix          # Minimal config
├── hardware-configuration.nix # Hardware detection
└── networking.nix             # Network settings from current system
```

## Migration Steps

### 1. Backup the generated configs

```bash
cd /etc/nixos
mkdir -p backup
cp configuration.nix backup/
cp hardware-configuration.nix backup/
cp networking.nix backup/
```

### 2. Clone your configuration

```bash
# Move current configs aside
mv /etc/nixos /etc/nixos.infect

# Clone your repo
git clone https://github.com/yourusername/dev-setup.git /etc/nixos
cd /etc/nixos
```

### 3. Extract useful parts from infect configs

#### A. Copy hardware-configuration.nix sections

The infect-generated `hardware-configuration.nix` has correct boot settings. You need:

```bash
# View the generated hardware config
cat /etc/nixos.infect/hardware-configuration.nix
```

Update your `hardware-configuration.nix` with:
- Boot loader settings (GRUB or EFI)
- Root filesystem device
- Kernel modules

#### B. Keep networking.nix (optional but recommended)

The generated `networking.nix` has your server's actual network configuration:

```bash
# Option 1: Keep it as-is
cp /etc/nixos.infect/networking.nix /etc/nixos/

# Then import it in configuration.nix
```

Or extract the values and put them in `machine-specific.nix`.

### 4. Create machine-specific.nix

```bash
# Copy the template
cp machine-specific.nix.example machine-specific.nix

# Edit with your actual values
vim machine-specific.nix
```

Find your volume device:
```bash
ls -la /dev/disk/by-id/ | grep Volume
```

Example `machine-specific.nix`:
```nix
{
  volumeDevice = "/dev/disk/by-id/scsi-0HC_Volume_103912881";
  hostname = "devserver";
  rootDevice = "/dev/sda";      # Check from hardware-configuration.nix
  rootPartition = "/dev/sda1";  # Check from hardware-configuration.nix
}
```

### 5. Update configuration.nix

Import the generated networking config:

```nix
{ config, pkgs, lib, ... }:

let
  machineSpecific = import ./machine-specific.nix;
in
{
  imports = [
    ./hardware-configuration.nix
    ./networking.nix  # <-- Add this line
  ];

  # Rest of your config...
}
```

Or if you want to manage networking yourself, remove the DHCP line:
```nix
# Remove or comment out:
# networking.useDHCP = true;
```

### 6. Copy SSH keys

Preserve your SSH authorized keys:

```bash
# The infect config has your keys, extract them
grep "authorizedKeys" /etc/nixos.infect/configuration.nix
```

Add to your `configuration.nix`:
```nix
users.users.root.openssh.authorizedKeys.keys = [
  "ssh-ed25519 AAAA... your-key-1"
  "ssh-ed25519 AAAA... your-key-2"
];

users.users.qwe.openssh.authorizedKeys.keys = [
  "ssh-ed25519 AAAA... your-key-1"
  "ssh-ed25519 AAAA... your-key-2"
];
```

### 7. Test the configuration

```bash
# Check for syntax errors
nix flake check

# Dry-run to see what would change
nixos-rebuild dry-build --flake .#devserver

# If all looks good, apply
nixos-rebuild switch --flake .#devserver
```

### 8. Reboot and test

```bash
reboot
```

After reboot:
```bash
# SSH back in as your user
ssh qwe@your-server-ip

# Verify volume is mounted
df -h | grep home

# Check services
systemctl status docker
systemctl status sshd

# Test your shell config
echo $SHELL
```

## Common Issues

### Issue: "cannot find machine-specific.nix"

```bash
cp machine-specific.nix.example machine-specific.nix
vim machine-specific.nix
```

### Issue: Boot fails after rebuild

You likely have incorrect boot settings. Boot into rescue mode and:

```bash
# Check generated hardware config
cat /etc/nixos.infect/hardware-configuration.nix

# Compare with yours
cat /etc/nixos/hardware-configuration.nix

# Copy the boot.loader section from infect's version
```

### Issue: Network not working

```bash
# Use the generated networking.nix
cp /etc/nixos.infect/networking.nix /etc/nixos/

# Add to configuration.nix imports
imports = [
  ./hardware-configuration.nix
  ./networking.nix
];

# Rebuild
nixos-rebuild switch --flake .#devserver
```

### Issue: Can't SSH in after rebuild

If you lose SSH access:

1. Access via Hetzner console
2. Check SSH service: `systemctl status sshd`
3. Check firewall: `iptables -L`
4. Verify keys: `cat ~/.ssh/authorized_keys`
5. Roll back: `nixos-rebuild switch --rollback`

## Alternative: Gradual Migration

If you want to be more careful:

### Step 1: Just add your packages

```nix
# Start with infect's configuration.nix
{ ... }: {
  imports = [
    ./hardware-configuration.nix
    ./networking.nix
  ];

  # Keep infect's settings
  boot.tmp.cleanOnBoot = true;
  zramSwap.enable = true;
  networking.hostName = "nix";
  services.openssh.enable = true;
  users.users.root.openssh.authorizedKeys.keys = [ "..." ];
  system.stateVersion = "24.05";

  # Add your stuff gradually
  environment.systemPackages = with pkgs; [
    vim git htop
  ];
}
```

### Step 2: Add volume mount

```nix
fileSystems."/home" = {
  device = "/dev/disk/by-id/scsi-0HC_Volume_103912881";
  fsType = "ext4";
  options = [ "discard" "defaults" ];
};
```

### Step 3: Add your user

```nix
users.users.qwe = {
  isNormalUser = true;
  home = "/home/qwe";
  extraGroups = [ "wheel" ];
  openssh.authorizedKeys.keys = [ "..." ];
};
```

### Step 4: Enable flakes and switch to your flake

```nix
nix.settings.experimental-features = [ "nix-command" "flakes" ];
```

Then:
```bash
nixos-rebuild switch --flake .#devserver
```

## Quick Script

Save this as `migrate.sh`:

```bash
#!/usr/bin/env bash
set -e

echo "=== NixOS Configuration Migration ==="

# Backup infect configs
echo "Backing up infect-generated configs..."
mkdir -p /etc/nixos.infect
cp /etc/nixos/*.nix /etc/nixos.infect/

# Clone your config
echo "Cloning your configuration..."
cd /etc/nixos
# (Manual: git clone your-repo .)

# Create machine-specific.nix
echo "Creating machine-specific.nix..."
cp machine-specific.nix.example machine-specific.nix

echo "Please edit machine-specific.nix with your device paths:"
echo "  vim machine-specific.nix"
echo ""
echo "Then run:"
echo "  nixos-rebuild switch --flake .#devserver"
```

## Summary

1. ✅ Backup infect configs
2. ✅ Clone your repo to /etc/nixos
3. ✅ Copy hardware-configuration.nix boot settings
4. ✅ Keep or adapt networking.nix
5. ✅ Create machine-specific.nix with device paths
6. ✅ Copy SSH keys to your config
7. ✅ Test and apply: `nixos-rebuild switch --flake .#devserver`
8. ✅ Reboot and verify

The key is to preserve the working boot configuration and networking while applying your user environment and packages!
