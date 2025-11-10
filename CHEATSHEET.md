# NixOS Quick Reference

## Essential Commands

### System Management

```bash
# Apply configuration changes
sudo nixos-rebuild switch --flake .#devserver

# Test configuration without switching
sudo nixos-rebuild test --flake .#devserver

# Build configuration without activating
sudo nixos-rebuild build --flake .#devserver

# Rollback to previous generation
sudo nixos-rebuild switch --rollback

# List all generations
sudo nix-env --list-generations --profile /nix/var/nix/profiles/system

# Switch to specific generation
sudo nixos-rebuild switch --switch-generation 42

# Update flake inputs (update all packages)
nix flake update
```

### User Environment (Home Manager)

```bash
# Apply home-manager changes (usually done via nixos-rebuild)
home-manager switch --flake .#qwe

# List home-manager generations
home-manager generations
```

### Package Management

```bash
# Search for packages
nix search nixpkgs <package-name>

# Show package info
nix-env -qa --description <package-name>

# Install package temporarily (doesn't persist)
nix-shell -p <package-name>

# Install package to user profile (not recommended with home-manager)
nix-env -iA nixpkgs.<package-name>

# List installed packages
nix-env -q

# Remove old packages and free space
sudo nix-collect-garbage --delete-older-than 30d

# Optimize nix store
nix-store --optimize
```

### Debugging

```bash
# Check configuration syntax
nix flake check

# Show flake info
nix flake show

# Build and show trace on error
nixos-rebuild switch --flake .#devserver --show-trace

# Dry run (show what would change)
nixos-rebuild dry-run --flake .#devserver

# Check systemd service status
systemctl status docker
systemctl status sshd

# View system logs
journalctl -xe
journalctl -u docker.service
```

## Common Tasks

### Add a Package

Edit `home.nix`:
```nix
home.packages = with pkgs; [
  existing-package
  new-package  # Add this line
];
```

Then apply:
```bash
sudo nixos-rebuild switch --flake .#devserver
```

### Update All Packages

```bash
cd /etc/nixos
nix flake update
sudo nixos-rebuild switch --flake .#devserver
```

### Change User Shell Config

Edit `home.nix`:
```nix
programs.zsh = {
  enable = true;
  shellAliases = {
    my-alias = "echo hello";
  };
};
```

Apply:
```bash
sudo nixos-rebuild switch --flake .#devserver
```

### Enable a System Service

Edit `configuration.nix`:
```nix
services.nginx = {
  enable = true;
  # ... config
};
```

Apply:
```bash
sudo nixos-rebuild switch --flake .#devserver
```

### Add SSH Key

Edit `configuration.nix`:
```nix
users.users.qwe.openssh.authorizedKeys.keys = [
  "ssh-ed25519 AAAA... user@host"
];
```

Apply:
```bash
sudo nixos-rebuild switch --flake .#devserver
```

### Change Firewall Rules

Edit `configuration.nix`:
```nix
networking.firewall = {
  enable = true;
  allowedTCPPorts = [ 80 443 8080 ];
};
```

Apply:
```bash
sudo nixos-rebuild switch --flake .#devserver
```

## File Locations

```
/etc/nixos/              # System configuration location
├── flake.nix            # Flake entry point
├── configuration.nix    # System config
├── home.nix            # User config (home-manager)
└── hardware-configuration.nix  # Hardware config

/nix/store/             # Immutable package store
/nix/var/nix/profiles/  # System generations

~/.config/home-manager/ # Home-manager state (managed by flake)
~/.nix-profile/         # User profile (avoid with home-manager)
```

## Troubleshooting

### Configuration won't apply

```bash
# Check syntax
nix flake check

# Show detailed errors
nixos-rebuild switch --flake .#devserver --show-trace

# Try building without switching
nixos-rebuild build --flake .#devserver
```

### System is broken after update

```bash
# Rollback immediately
sudo nixos-rebuild switch --rollback

# Or reboot and select previous generation from boot menu
sudo reboot
```

### Package not found

```bash
# Update flake inputs
nix flake update

# Search for package
nix search nixpkgs <package-name>

# Check if package exists in nixpkgs
open https://search.nixos.org/packages?query=<package-name>
```

### Docker not working

```bash
# Check if service is running
systemctl status docker

# Restart docker
sudo systemctl restart docker

# Check if user is in docker group
groups qwe

# Check docker daemon logs
journalctl -u docker.service -f
```

### Home-manager conflicts

```bash
# Remove conflicting packages
nix-env -e <package-name>

# Let home-manager manage everything
home-manager switch --flake .#qwe
```

### Out of disk space

```bash
# Clean up old generations
sudo nix-collect-garbage --delete-older-than 7d

# Optimize store (deduplicate)
nix-store --optimize

# Check disk usage
du -sh /nix/store
nix-store --query --requisites /run/current-system | du -ch -f -
```

## Best Practices

### 1. Version Control
```bash
cd /etc/nixos
git init
git add .
git commit -m "Initial configuration"
git remote add origin <your-repo>
git push -u origin main
```

### 2. Test Before Applying
```bash
# Build VM
nix run nixpkgs#nixos-rebuild -- build-vm --flake .#devserver

# Or test without switching
nixos-rebuild test --flake .#devserver
```

### 3. Keep Generations Clean
```bash
# Weekly cleanup
sudo nix-collect-garbage --delete-older-than 30d

# Keep 5 most recent generations
sudo nix-env --delete-generations +5 --profile /nix/var/nix/profiles/system
```

### 4. Pin Important Inputs
In `flake.nix`:
```nix
inputs = {
  # Pin to specific commit
  nixpkgs.url = "github:NixOS/nixpkgs/abc123def456";
};
```

### 5. Use Module System
Split large configs:
```nix
# configuration.nix
imports = [
  ./hardware-configuration.nix
  ./services.nix
  ./users.nix
];
```

## Getting Help

- **NixOS Manual**: `nixos-help` or https://nixos.org/manual/nixos/stable/
- **Package Search**: https://search.nixos.org/packages
- **NixOS Options**: https://search.nixos.org/options
- **Home-Manager Options**: https://nix-community.github.io/home-manager/options.html
- **NixOS Wiki**: https://nixos.wiki/
- **Discourse Forum**: https://discourse.nixos.org/
- **Matrix Chat**: #nixos:nixos.org
- **Reddit**: r/NixOS

## Emergency Recovery

If system won't boot:

1. **Boot into previous generation** from GRUB menu
2. **Or boot from rescue system**:
   ```bash
   # Mount root
   mount /dev/sda1 /mnt

   # Chroot into system
   nixos-enter --root /mnt

   # Rollback
   nixos-rebuild switch --rollback
   ```

## Quick Wins

```bash
# See what would be downloaded
nix build --dry-run .#nixosConfigurations.devserver.config.system.build.toplevel

# Diff between generations
nix store diff-closures /nix/var/nix/profiles/system-{41,42}-link

# Why is package in closure?
nix why-depends /run/current-system nixpkgs#htop

# Repair nix store
nix-store --verify --check-contents --repair
```

## Aliases (add to home.nix)

```nix
programs.zsh.shellAliases = {
  # NixOS shortcuts
  nrs = "sudo nixos-rebuild switch --flake .#devserver";
  nrt = "sudo nixos-rebuild test --flake .#devserver";
  nrb = "sudo nixos-rebuild build --flake .#devserver";
  nfu = "nix flake update";
  ngc = "sudo nix-collect-garbage --delete-older-than 30d";

  # List generations
  ngl = "sudo nix-env --list-generations --profile /nix/var/nix/profiles/system";

  # Search packages
  nsp = "nix search nixpkgs";
};
```
