# NixOS Bootstrap Process

## The Chicken-and-Egg Problem

When installing NixOS (via `nixos-infect` or manual install), the Nix store goes to `/nix` on the root disk. But we want it on the persistent volume!

## Solution: Two-Phase Setup

### Phase 1: Initial NixOS Installation

1. **Install NixOS** (via nixos-infect or manual)
   ```bash
   curl https://raw.githubusercontent.com/elitak/nixos-infect/master/nixos-infect | \
     NIX_CHANNEL=nixos-unstable bash
   ```

   After reboot, you have:
   - `/nix/store` on root disk
   - Volume not yet mounted

2. **Prepare the volume**
   ```bash
   # Format volume (if new)
   mkfs.ext4 /dev/disk/by-id/scsi-0HC_Volume_103912881

   # Mount temporarily
   mkdir -p /mnt/volume
   mount /dev/disk/by-id/scsi-0HC_Volume_103912881 /mnt/volume

   # Create directory structure
   mkdir -p /mnt/volume/qwe/nix
   ```

3. **Copy existing Nix store to volume**
   ```bash
   # This preserves all packages installed during nixos-infect
   rsync -av /nix/ /mnt/volume/qwe/nix/

   # Verify
   ls -la /mnt/volume/qwe/nix/store/  # Should show packages
   ```

4. **Remove old /nix**
   ```bash
   # Backup just in case
   mv /nix /nix.bak
   mkdir /nix
   ```

### Phase 2: Apply Configuration

5. **Clone and apply configuration**
   ```bash
   git clone <your-repo> /etc/nixos
   cd /etc/nixos

   # Generate hardware config
   nixos-generate-config --show-hardware-config > hardware-configuration.nix

   # Apply - this will bind mount /nix to volume
   nixos-rebuild switch --flake .#devserver
   ```

6. **Verify and cleanup**
   ```bash
   # Check that /nix is bind mounted
   mount | grep /nix
   # Should show: /home/qwe/nix on /nix type none (bind)

   # Check packages are accessible
   ls -la /nix/store/

   # Remove backup if everything works
   rm -rf /nix.bak
   ```

## Automated Bootstrap Script

Here's a script to automate this:

```bash
#!/usr/bin/env bash
set -euo pipefail

VOLUME_DEV="/dev/disk/by-id/scsi-0HC_Volume_103912881"
REPO_URL="<your-git-repo-url>"

echo "=== NixOS Volume Bootstrap ==="

# 1. Format volume (if needed)
if ! blkid "$VOLUME_DEV" | grep -q "TYPE=\"ext4\""; then
  read -p "Volume not formatted. Format as ext4? (yes/no): " -r
  if [[ $REPLY == "yes" ]]; then
    mkfs.ext4 -F "$VOLUME_DEV"
  else
    exit 1
  fi
fi

# 2. Mount volume temporarily
mkdir -p /mnt/volume
mount "$VOLUME_DEV" /mnt/volume

# 3. Create directory structure
mkdir -p /mnt/volume/qwe/nix

# 4. Copy existing /nix to volume
echo "Copying /nix to volume (this may take a few minutes)..."
rsync -av --info=progress2 /nix/ /mnt/volume/qwe/nix/

# 5. Backup and remove old /nix
mv /nix /nix.bak
mkdir /nix

# 6. Clone configuration
git clone "$REPO_URL" /etc/nixos
cd /etc/nixos

# 7. Generate hardware config
nixos-generate-config --show-hardware-config > hardware-configuration.nix

# 8. Apply configuration (this bind mounts /nix)
nixos-rebuild switch --flake .#devserver

# 9. Verify
if mount | grep -q "/home/qwe/nix on /nix"; then
  echo "✅ Success! /nix is bind mounted to volume"
  echo "Removing backup..."
  rm -rf /nix.bak
  umount /mnt/volume
  rmdir /mnt/volume
  echo "Bootstrap complete!"
else
  echo "❌ Error: /nix not properly mounted"
  echo "Restoring backup..."
  rmdir /nix
  mv /nix.bak /nix
  exit 1
fi
```

## Alternative: Fresh NixOS Installation

If you're doing a **fresh install** (not nixos-infect), you can set it up correctly from the start:

### During NixOS Installation

1. **Partition setup**:
   ```bash
   # Root partition
   mkfs.ext4 /dev/sda1
   mount /dev/sda1 /mnt

   # Mount volume
   mkdir -p /mnt/home
   mount /dev/disk/by-id/scsi-0HC_Volume_103912881 /mnt/home

   # Bind mount /nix before installation
   mkdir -p /mnt/home/qwe/nix
   mkdir -p /mnt/nix
   mount --bind /mnt/home/qwe/nix /mnt/nix
   ```

2. **Generate config**:
   ```bash
   nixos-generate-config --root /mnt
   ```

3. **Edit configuration** before installation:
   ```nix
   # /mnt/etc/nixos/configuration.nix
   fileSystems."/home" = {
     device = "/dev/disk/by-id/scsi-0HC_Volume_103912881";
     fsType = "ext4";
   };

   fileSystems."/nix" = {
     device = "/home/qwe/nix";
     fsType = "none";
     options = [ "bind" ];
     depends = [ "/home" ];
   };
   ```

4. **Install**:
   ```bash
   nixos-install
   reboot
   ```

Now `/nix` is on the volume from the start!

## Why This Matters

### Without Proper Bootstrap:
```
/nix/store (on root disk)     /home/qwe/nix/store (on volume)
      ↓                                 ↓
  Packages from install           Empty or outdated
      ↓                                 ↓
  Bind mount tries to overlay them
      ↓
  ❌ Confusion, wasted space, potential errors
```

### With Proper Bootstrap:
```
/nix/store                    /home/qwe/nix/store (on volume)
      ↓ bind mount                     ↓
      └──────────────────────────────> Actual data here
                                        ↓
                                   ✅ Single source of truth
```

## Verification Commands

After bootstrap, verify everything is correct:

```bash
# 1. Check mount points
mount | grep -E "/home|/nix"
# Should show:
# - /dev/... on /home type ext4 ...
# - /home/qwe/nix on /nix type none (bind)

# 2. Check /nix is NOT consuming root disk space
df -h /nix
# Should show same device as /home

# 3. Verify packages are accessible
ls -la /nix/store/ | head

# 4. Test that new packages go to volume
nix-shell -p hello
which hello  # Should show /nix/store/...-hello-...
df -h /nix   # Size should match /home
```

## Common Mistakes

### ❌ Applying config without moving /nix first
```bash
nixos-rebuild switch --flake .#devserver
# Tries to bind mount over existing /nix
# May hide existing packages or cause conflicts
```

### ✅ Correct approach
```bash
# 1. Move /nix to volume
rsync -av /nix/ /mnt/volume/qwe/nix/
mv /nix /nix.bak
mkdir /nix

# 2. Then apply config
nixos-rebuild switch --flake .#devserver
```

## For Subsequent VPS Changes

Once properly set up, future VPS changes are simple:

```bash
# New VPS with NixOS installed
# Volume already has /qwe/nix with all packages

git clone <repo> /etc/nixos
cd /etc/nixos
nixos-rebuild switch --flake .#devserver

# /nix is empty on new VPS, so bind mount just works!
# Instant access to all packages on volume
```

No rsync needed - the volume already has everything.

## Summary

**First time setup requires:**
1. Install NixOS (nixos-infect or manual)
2. Copy `/nix` to volume
3. Apply configuration with bind mount

**Subsequent VPS changes:**
1. Just apply configuration
2. Bind mount works immediately (volume has data)

This bootstrap process is **one-time** per volume, not per VPS!
