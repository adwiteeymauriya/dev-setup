# Custom NixOS Infect with Volume Support

This is a modified version of `nixos-infect` that supports Hetzner Cloud volumes from the start, eliminating bootstrap complexity.

## Key Modifications

1. **Volume Detection**: Accepts `VOLUME_DEVICE` environment variable
2. **Automatic Volume Setup**: Formats and configures volume during installation
3. **Optional /nix Persistence**: Can optionally put `/nix` on volume via `NIX_ON_VOLUME`
4. **No Bootstrap Needed**: Everything is set up correctly from the start

## Usage

### Simple Setup (Recommended)

Volume for `/home` only, `/nix` on root disk:

```bash
# On your Debian/Ubuntu Hetzner VPS
VOLUME_DEVICE="/dev/disk/by-id/scsi-0HC_Volume_103912881" \
  NIX_CHANNEL=nixos-unstable \
  bash nixos-infect-custom
```

After reboot:
```bash
# /home is on volume
# /nix is on root disk (ephemeral, but fast to rebuild)
```

### Advanced Setup

Volume for both `/home` and `/nix`:

```bash
# On your Debian/Ubuntu Hetzner VPS
VOLUME_DEVICE="/dev/disk/by-id/scsi-0HC_Volume_103912881" \
  NIX_ON_VOLUME="yes" \
  NIX_CHANNEL=nixos-unstable \
  bash nixos-infect-custom
```

After reboot:
```bash
# /home is on volume
# /nix is bind-mounted to volume (persistent packages!)
```

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `VOLUME_DEVICE` | (none) | Block device path for volume |
| `VOLUME_MOUNT` | `/home` | Where to mount the volume |
| `NIX_ON_VOLUME` | `no` | Set to `yes` for persistent /nix |
| `NIX_CHANNEL` | `nixos-24.05` | NixOS channel to use |
| `NO_REBOOT` | (none) | Set to skip automatic reboot |

## How It Works

### Without NIX_ON_VOLUME (Simple)

1. Formats volume as ext4 (if needed)
2. Installs NixOS with `/nix` on root disk
3. Configures volume mount in `/etc/nixos/hardware-configuration.nix`
4. `/home` will be on volume after reboot

**Result:**
- `/home` persistent on volume
- `/nix` ephemeral (rebuilt ~10-20 min on new VPS)

### With NIX_ON_VOLUME=yes (Advanced)

1. Formats volume as ext4 (if needed)
2. Installs NixOS normally
3. Copies `/nix` to volume after installation
4. Configures bind mount in `/etc/nixos/hardware-configuration.nix`
5. `/nix` and `/home` will be on volume after reboot

**Result:**
- `/home` persistent on volume
- `/nix` persistent on volume (instant access on new VPS)

## Generated Configuration

The script generates `/etc/nixos/hardware-configuration.nix` with:

```nix
{ modulesPath, ... }:
{
  imports = [ (modulesPath + "/profiles/qemu-guest.nix") ];

  # Boot configuration
  boot.loader.grub.device = "/dev/sda";
  boot.initrd.availableKernelModules = [ "ata_piix" "uhci_hcd" "xen_blkfront" ];

  # Root filesystem
  fileSystems."/" = { device = "/dev/sda1"; fsType = "ext4"; };

  # Volume mount (always added)
  fileSystems."/home" = {
    device = "/dev/disk/by-id/scsi-0HC_Volume_103912881";
    fsType = "ext4";
    options = [ "discard" "defaults" ];
  };

  # /nix bind mount (only if NIX_ON_VOLUME=yes)
  fileSystems."/nix" = {
    device = "/home/nix";
    fsType = "none";
    options = [ "bind" ];
    depends = [ "/home" ];
  };
}
```

## After Installation

After reboot, you can apply your own configuration:

```bash
# Clone your configuration
git clone <your-repo> /etc/nixos
cd /etc/nixos

# Apply your config (overwrites infect-generated config)
nixos-rebuild switch --flake .#devserver
```

## Comparison

### Original nixos-infect

```bash
curl https://raw.githubusercontent.com/elitak/nixos-infect/master/nixos-infect | bash
# Reboot
# Manually format volume
# Manually copy /nix to volume (if wanted)
# Apply configuration
```

### Custom nixos-infect

```bash
VOLUME_DEVICE="/dev/disk/by-id/..." bash nixos-infect-custom
# Reboot
# Apply configuration (volume already configured!)
```

## Example: Full Workflow

```bash
# 1. On Debian/Ubuntu Hetzner VPS with volume attached
wget https://your-repo/nixos-infect-custom
chmod +x nixos-infect-custom

# 2. Find your volume device
ls -la /dev/disk/by-id/ | grep Volume

# 3. Run custom infect
VOLUME_DEVICE="/dev/disk/by-id/scsi-0HC_Volume_103912881" \
  NIX_CHANNEL=nixos-unstable \
  bash nixos-infect-custom

# System will reboot automatically

# 4. After reboot, SSH back in and apply your config
git clone https://github.com/yourname/nixos-config /etc/nixos
cd /etc/nixos
nixos-rebuild switch --flake .#devserver

# Done! Volume is configured and persistent
```

## Troubleshooting

### Volume not detected

```bash
# Check if volume is attached
lsblk
ls -la /dev/disk/by-id/

# Make sure you're using the full path
VOLUME_DEVICE="/dev/disk/by-id/scsi-0HC_Volume_XXXXX"
```

### Volume already has data

The script will NOT format if the volume already has a filesystem:

```bash
blkid /dev/disk/by-id/scsi-0HC_Volume_103912881
# If shows TYPE="ext4", it will NOT be reformatted
```

### Want to change NIX_ON_VOLUME after installation

Edit `/etc/nixos/configuration.nix`:

```nix
# Add or remove this section:
fileSystems."/nix" = {
  device = "/home/nix";
  fsType = "none";
  options = [ "bind" ];
  depends = [ "/home" ];
};
```

Then:
```bash
# If adding /nix on volume:
mkdir -p /home/nix
rsync -av /nix/ /home/nix/
mv /nix /nix.bak
mkdir /nix

nixos-rebuild switch

# If removing /nix from volume:
# Just remove the fileSystems."/nix" section and rebuild
nixos-rebuild switch
```

## Advantages

✅ **No bootstrap needed** - Volume configured during installation
✅ **Idempotent** - Safe to rerun
✅ **Flexible** - Choose ephemeral or persistent /nix
✅ **Clean** - Generated config is minimal
✅ **Compatible** - Works with existing nixos-infect options

## Limitations

- Only tested on Hetzner Cloud
- Only supports ext4 volumes
- Requires volume attached before running
- Cannot change volume mount point after installation (without manual work)

## Source

Modified from: https://github.com/elitak/nixos-infect

Changes:
- Added `prepareVolume()` function
- Added `moveNixToVolume()` function
- Modified `makeConf()` to generate volume mounts
- Added environment variable support for volume configuration
