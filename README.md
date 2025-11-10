# NixOS Development Server Configuration

A fully declarative, reproducible development environment for Hetzner Cloud using NixOS and flakes.

## Features

- **Declarative system configuration** - Everything in code
- **Persistent storage** - Home directory and /nix on external volume
- **User environment** - Managed via home-manager
- **Development tools** - Node.js, Python (uv), Devbox, Docker
- **Shell setup** - Zsh with Oh-My-Zsh, Starship prompt, useful aliases
- **Zero maintenance** - Reproducible across rebuilds

## Architecture

```
flake.nix           → Entry point, defines inputs/outputs
configuration.nix   → System-level config (boot, users, docker, ssh)
home.nix           → User-level config (packages, shell, dotfiles)
```

## Initial Setup on Hetzner

### Prerequisites

1. **NixOS installed** on your Hetzner instance
   - Use Hetzner's NixOS image, or
   - Use [nixos-infect](https://github.com/elitak/nixos-infect) to convert existing Debian/Ubuntu:
     ```bash
     curl https://raw.githubusercontent.com/elitak/nixos-infect/master/nixos-infect | \
       NIX_CHANNEL=nixos-unstable bash
     ```

2. **Volume attached** to your instance
   - Attach the Hetzner volume via cloud console
   - Note the device path (e.g., `/dev/disk/by-id/scsi-0HC_Volume_103912881`)

### Setup Steps

1. **Format the volume** (one-time, if new volume):
   ```bash
   # Check available devices
   ls -la /dev/disk/by-id/

   # Format as ext4 (DESTRUCTIVE - only if new/empty volume!)
   mkfs.ext4 /dev/disk/by-id/scsi-0HC_Volume_103912881
   ```

2. **Clone this configuration**:
   ```bash
   git clone <your-repo-url> /etc/nixos
   cd /etc/nixos
   ```

3. **Generate hardware configuration**:
   ```bash
   nixos-generate-config --show-hardware-config > hardware-configuration.nix
   ```

4. **Review and adjust configuration.nix**:
   - Verify volume device path matches your system
   - Adjust root filesystem device if needed
   - Update username/UID/GID if desired
   - Add SSH public keys

5. **Apply the configuration**:
   ```bash
   nixos-rebuild switch --flake .#devserver
   ```

6. **Reboot** (recommended for first-time setup):
   ```bash
   reboot
   ```

That's it! No bash scripts needed. Everything is declarative.

### What NixOS Handles Automatically

When you run `nixos-rebuild switch --flake .#devserver`, NixOS will:

- ✅ Mount all filesystems (including the volume and /nix bind mount)
- ✅ Create the user `qwe` with correct UID/GID
- ✅ Set up passwordless sudo
- ✅ Configure and start SSH service
- ✅ Install and start Docker
- ✅ Install all system packages
- ✅ Apply home-manager configuration (dev tools, shell, etc.)
- ✅ Set proper file permissions

**The only manual step**: Formatting the volume initially (if it's a new/empty volume).

## Usage

### Updating the system

1. **Edit configuration**:
   - System changes: Edit `configuration.nix`
   - User environment: Edit `home.nix`
   - Add packages: Update `flake.nix` inputs if needed

2. **Apply changes**:
   ```bash
   sudo nixos-rebuild switch --flake .#devserver
   ```

3. **Update all packages**:
   ```bash
   nix flake update
   sudo nixos-rebuild switch --flake .#devserver
   ```

### Adding new packages

**System-wide** (available to all users):
```nix
# configuration.nix
environment.systemPackages = with pkgs; [
  htop
  neofetch
];
```

**User-specific** (only for qwe):
```nix
# home.nix
home.packages = with pkgs; [
  neovim
  lazygit
];
```

### Rollback

If something breaks:
```bash
# List generations
sudo nixos-rebuild list-generations

# Rollback to previous generation
sudo nixos-rebuild switch --rollback
```

## File Locations

- **System config**: `/etc/nixos/`
- **User home**: `/home/qwe` (persistent volume)
- **Nix store**: `/nix` (bind-mounted to `/home/qwe/nix`)
- **Home-manager**: `~/.config/home-manager/` (managed by flake)

## Customization

### Change username/UID/GID

Edit `configuration.nix`:
```nix
users.users.yourname = {
  uid = 1001;
  group = "yourname";
  # ...
};
```

### Change volume device

Edit `configuration.nix`:
```nix
fileSystems."/home" = {
  device = "/dev/disk/by-id/YOUR-VOLUME-ID";
  # ...
};
```

### Add SSH keys

Place your public keys in `/root/.ssh/authorized_keys` before first boot, or edit:
```nix
users.users.qwe.openssh.authorizedKeys.keys = [
  "ssh-ed25519 AAAA... your-key"
];
```

## Benefits over Bash Script

| Bash Script | NixOS Flake |
|-------------|-------------|
| Imperative | Declarative |
| Manual updates | Atomic updates |
| No rollback | Easy rollback |
| Drift over time | Always reproducible |
| Manual dependencies | Automatic dependencies |
| Hard to test | Test in VM |

## Persistent vs Ephemeral

### Persistent (survives rebuilds):
- `/home/qwe` - User data
- `/nix` - Packages (via bind mount)

### Ephemeral (reset on rebuild):
- `/` - Root filesystem
- System configuration (managed by NixOS)

This means you can destroy and recreate the server anytime, just reattach the volume and run `nixos-rebuild switch`.

## Maintenance

### Garbage collection
```bash
# Remove old generations and unused packages
sudo nix-collect-garbage --delete-older-than 30d
```

### Optimize store
```bash
nix-store --optimize
```

## Troubleshooting

### Volume not mounting
Check device path:
```bash
ls -la /dev/disk/by-id/
```

Update `configuration.nix` with correct path.

### Home-manager conflicts
Rebuild home-manager separately:
```bash
home-manager switch --flake .#qwe
```

### Docker not working
Ensure user is in docker group (already configured):
```bash
groups qwe
```

Reboot if needed:
```bash
sudo reboot
```

## Next Steps

1. **Version control**: Push this configuration to a private Git repo
2. **Secrets management**: Use [sops-nix](https://github.com/Mic92/sops-nix) for secrets
3. **Multiple machines**: Add more nixosConfigurations in flake.nix
4. **CI/CD**: Auto-deploy on config changes
5. **Project environments**: Use `devbox` or `flake.nix` per project

## Resources

- [NixOS Manual](https://nixos.org/manual/nixos/stable/)
- [Home Manager Manual](https://nix-community.github.io/home-manager/)
- [Nix Package Search](https://search.nixos.org/packages)
- [NixOS Wiki](https://nixos.wiki/)
