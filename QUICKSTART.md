# Quick Start Guide

## TL;DR - Pure NixOS Setup

### One-Time Setup

```bash
# 1. Install NixOS (if not already)
curl https://raw.githubusercontent.com/elitak/nixos-infect/master/nixos-infect | \
  NIX_CHANNEL=nixos-unstable bash

# (reboot into NixOS)

# 2. Format volume (only if new/empty)
mkfs.ext4 /dev/disk/by-id/scsi-0HC_Volume_103912881

# 3. Clone and apply configuration
git clone <your-repo> /etc/nixos
cd /etc/nixos
nixos-generate-config --show-hardware-config > hardware-configuration.nix
nixos-rebuild switch --flake .#devserver

# Done! ✨
```

## What You Get

A fully configured development server with:
- User `qwe` (UID 1000, passwordless sudo)
- Persistent `/home` on external volume
- Persistent `/nix` (bind mounted to volume)
- Docker installed and running
- Development tools: Node.js, Python (uv), Devbox
- Zsh with Oh-My-Zsh, Starship prompt
- Git, tmux, direnv configured

## Making Changes

Edit the configuration files:
- `configuration.nix` - System settings (users, services, mounts)
- `home.nix` - User environment (packages, shell, dotfiles)

Apply changes:
```bash
sudo nixos-rebuild switch --flake .#devserver
```

Something broke? Rollback instantly:
```bash
sudo nixos-rebuild switch --rollback
```

## No Bash Scripts

Unlike the old `setup_dev.sh`, everything is declarative:

| Old Way (Bash) | New Way (NixOS) |
|----------------|-----------------|
| `useradd ...` | `users.users.qwe = {...}` |
| `curl \| bash` installers | `home.packages = [ pkgs.devbox ]` |
| `echo >> .zshrc` | `programs.zsh = {...}` |
| Manual Docker install | `virtualisation.docker.enable = true` |
| Check if installed | Always idempotent |
| No rollback | Instant rollback |

## Key Files

```
/etc/nixos/
├── flake.nix              # Entry point
├── configuration.nix      # System config
├── home.nix              # User config
└── hardware-configuration.nix  # Auto-generated

/home/qwe/                # Your persistent data
└── nix/                  # Persistent Nix store
```

## Common Operations

### Add a package
```nix
# home.nix
home.packages = with pkgs; [
  neovim
  lazygit
];
```

### Update all packages
```bash
nix flake update
sudo nixos-rebuild switch --flake .#devserver
```

### Enable a service
```nix
# configuration.nix
services.nginx.enable = true;
```

### Add firewall rule
```nix
# configuration.nix
networking.firewall.allowedTCPPorts = [ 8080 ];
```

## Pure NixOS Benefits

✅ **Declarative** - Configuration as code
✅ **Reproducible** - Same result every time
✅ **Atomic** - Updates are all-or-nothing
✅ **Rollback** - Instant recovery from mistakes
✅ **Testable** - Build VM before applying
✅ **Version Controlled** - Git tracks everything
✅ **No Drift** - System matches configuration always

## Getting Help

- Options search: https://search.nixos.org/options
- Package search: https://search.nixos.org/packages
- NixOS Manual: https://nixos.org/manual/nixos/stable/
- Home Manager: https://nix-community.github.io/home-manager/

---

**The only manual step**: Formatting the volume (one-time).

**Everything else**: Handled by NixOS declaratively.
