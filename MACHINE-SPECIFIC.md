# Machine-Specific Configuration

This configuration uses a separate `machine-specific.nix` file to store device paths and settings that vary per server.

## Why?

- **Easy deployment** - Just edit one file per server
- **Git-friendly** - Template tracked, actual values not committed
- **Clean** - Separates machine-specific from reusable config
- **Safe** - Prevents accidentally committing device IDs

## Setup on a New Server

### 1. Copy the template

```bash
cd /etc/nixos
cp machine-specific.nix.example machine-specific.nix
```

### 2. Find your device paths

```bash
# Find volume device
ls -la /dev/disk/by-id/ | grep Volume
# Example output: scsi-0HC_Volume_103912881

# Find root device
lsblk
# Look for the boot disk (usually sda or vda)
```

### 3. Edit machine-specific.nix

```bash
vim machine-specific.nix
```

Update with your actual values:
```nix
{
  volumeDevice = "/dev/disk/by-id/scsi-0HC_Volume_103912881";
  hostname = "myserver";
  rootDevice = "/dev/sda";
  rootPartition = "/dev/sda1";
}
```

### 4. Apply configuration

```bash
sudo nixos-rebuild switch --flake .#devserver
```

## What's Configured

The `machine-specific.nix` file currently controls:

- **volumeDevice** - Persistent volume device path
- **hostname** - Server hostname
- **rootDevice** - GRUB installation target
- **rootPartition** - Root filesystem device

## Adding More Variables

To add more machine-specific settings:

### 1. Add to machine-specific.nix

```nix
{
  volumeDevice = "/dev/disk/by-id/...";
  hostname = "devserver";
  # Add new variables
  sshPort = 22;
  timezone = "America/New_York";
}
```

### 2. Use in configuration.nix

```nix
let
  machineSpecific = import ./machine-specific.nix;
in
{
  services.openssh.port = machineSpecific.sshPort;
  time.timeZone = machineSpecific.timezone;
}
```

### 3. Update the example template

```bash
# Edit machine-specific.nix.example to show new options
```

## Multiple Servers

For multiple servers, you can:

### Option A: Keep separate files locally

```bash
# On each server
/etc/nixos/machine-specific.nix  # Different on each server
```

### Option B: Use different flake outputs

Edit `flake.nix`:
```nix
outputs = { self, nixpkgs, ... }: {
  nixosConfigurations = {
    server1 = nixpkgs.lib.nixosSystem {
      modules = [
        ./configuration.nix
        { networking.hostName = "server1"; }
        { fileSystems."/home".device = "/dev/disk/by-id/scsi-0HC_Volume_111"; }
      ];
    };
    server2 = nixpkgs.lib.nixosSystem {
      modules = [
        ./configuration.nix
        { networking.hostName = "server2"; }
        { fileSystems."/home".device = "/dev/disk/by-id/scsi-0HC_Volume_222"; }
      ];
    };
  };
};
```

Then deploy with:
```bash
nixos-rebuild switch --flake .#server1
nixos-rebuild switch --flake .#server2
```

## Git Workflow

The `.gitignore` is configured to:
- ✅ Track `machine-specific.nix.example` (template)
- ❌ Ignore `machine-specific.nix` (actual values)

This means:
- You can commit and push config changes
- Each server keeps its own device paths locally
- No risk of leaking server-specific info

## Troubleshooting

### Error: cannot find machine-specific.nix

```bash
# You forgot to create it
cp machine-specific.nix.example machine-specific.nix
vim machine-specific.nix
```

### Wrong device path

```bash
# Check actual devices
ls -la /dev/disk/by-id/
lsblk

# Update machine-specific.nix
vim machine-specific.nix

# Rebuild
sudo nixos-rebuild switch --flake .#devserver
```

### Want to track machine-specific.nix in git

```bash
# Remove from .gitignore
sed -i '/machine-specific.nix/d' .gitignore

# Commit it
git add machine-specific.nix
git commit -m "Add machine-specific config"
```

## Alternative Approaches

If you don't like this approach, you can also:

1. **Use flake inputs** - Pass values via `--override-input`
2. **Environment variables** - Use `builtins.getEnv` (not recommended)
3. **NixOS modules with options** - More complex but very flexible
4. **Separate repos per server** - Simple but harder to share common config

The current approach (separate file) is a good balance of simplicity and flexibility.
