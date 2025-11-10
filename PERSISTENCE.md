# NixOS Persistence Strategy

## Overview

This setup uses a Hetzner volume to persist critical data across VPS rebuilds. You can destroy and recreate the VPS while keeping all your data.

## Persistent Storage Architecture

```
VPS (Ephemeral)                Volume (Persistent)
├── / (root)                   /home/
├── /boot                      ├── qwe/
└── /etc/nixos ─────┐          │   ├── .ssh/
                    │          │   ├── projects/
                    │          │   ├── .config/
                    └──────────┤   └── nix/        ← Nix store
                               └── nixos-config/   ← Config backup
                                   └── /etc/nixos  (optional)
```

## What's Persistent (Survives VPS Changes)

### User Data
```nix
fileSystems."/home" = {
  device = "/dev/disk/by-id/scsi-0HC_Volume_103912881";
  fsType = "ext4";
};
```
- All files in `/home/qwe`
- SSH keys
- Git repositories
- Project files
- Dotfiles managed by home-manager

### Nix Store
```nix
fileSystems."/nix" = {
  device = "/home/qwe/nix";
  fsType = "none";
  options = [ "bind" ];
};
```
- All installed packages
- Binary cache
- No need to redownload packages!

## What's Ephemeral (Rebuilt Each Time)

### System Root
- Operating system files
- Boot configuration
- Systemd units
- `/etc` (except what you make persistent)

**Why this is OK:**
NixOS rebuilds these from your configuration files. They're deterministic and reproducible.

## Configuration Persistence Options

### Option 1: Git Only (Recommended)

Keep configuration in Git:
```bash
cd /etc/nixos
git init
git remote add origin <your-repo>
git push
```

**On new VPS:**
```bash
git clone <your-repo> /etc/nixos
nixos-rebuild switch --flake .#devserver
```

**Pros:**
- ✅ Version controlled
- ✅ Easy to track changes
- ✅ Can have multiple branches
- ✅ Works without volume

**Cons:**
- ❌ Need to clone on new VPS

### Option 2: Bind Mount /etc/nixos to Volume

Make configuration persistent on volume:

```nix
# configuration.nix
fileSystems."/etc/nixos" = {
  device = "/home/qwe/nixos-config";
  fsType = "none";
  options = [ "bind" ];
};
```

**Pros:**
- ✅ Configuration on volume
- ✅ No need to clone

**Cons:**
- ❌ Circular dependency (chicken-egg problem)
- ❌ Harder initial setup
- ❌ Still need Git for version control

**Recommendation:** Use Option 1 (Git only). It's simpler and more flexible.

### Option 3: Hybrid Approach

Keep config in Git AND have a backup on volume:

```bash
# On VPS
cd /etc/nixos
git init
git remote add origin <your-repo>
git push

# Also backup to volume
mkdir -p /home/qwe/nixos-config-backup
cp -r /etc/nixos/* /home/qwe/nixos-config-backup/

# Or use a git hook to auto-backup
```

## Docker Data Persistence

If using Docker volumes, keep them on the persistent volume:

```nix
# configuration.nix
virtualisation.docker = {
  enable = true;
  dataRoot = "/home/qwe/docker";  # Store Docker data on volume
};
```

Now Docker images and volumes survive VPS changes too!

## Complete Disaster Recovery Workflow

### Before Destroying VPS

```bash
# 1. Push configuration to Git
cd /etc/nixos
git add .
git commit -m "Latest config"
git push

# 2. (Optional) Note what's installed
nix-env -q > /home/qwe/installed-packages.txt
home-manager packages > /home/qwe/hm-packages.txt

# 3. Destroy VPS (keep volume!)
```

### Creating New VPS

```bash
# 1. Create new VPS with NixOS
# 2. Attach existing volume (DON'T FORMAT IT!)

# 3. Mount volume temporarily to check
mkdir /mnt/data
mount /dev/disk/by-id/scsi-0HC_Volume_103912881 /mnt/data
ls -la /mnt/data/qwe  # Verify data is there
umount /mnt/data

# 4. Clone configuration
git clone <your-repo> /etc/nixos
cd /etc/nixos

# 5. Generate hardware config for new VPS
nixos-generate-config --show-hardware-config > hardware-configuration.nix

# 6. Apply configuration
nixos-rebuild switch --flake .#devserver

# 7. Reboot
reboot

# Done! Everything restored:
# - User data in /home/qwe
# - All Nix packages
# - All settings from home-manager
```

## Testing Volume Persistence

You can test this without destroying your VPS:

```bash
# 1. Create test file on volume
echo "test" > /home/qwe/persistence-test.txt

# 2. Note current Nix store size
du -sh /nix/store

# 3. Simulate by doing a rollback
nixos-rebuild switch --rollback

# 4. Check data is still there
cat /home/qwe/persistence-test.txt  # Should show "test"
du -sh /nix/store  # Should be same size
```

## What Happens During VPS Change

### Step-by-Step

1. **Detach volume** from old VPS
2. **Destroy old VPS** (root disk gone)
3. **Create new VPS** (fresh root disk)
4. **Attach volume** to new VPS
5. **Apply NixOS config** from Git
6. **NixOS mounts volume** as `/home`
7. **NixOS bind-mounts** `/home/qwe/nix` to `/nix`
8. **User created** with correct UID (1000)
9. **Home-manager activates** user config
10. **Everything works** as before!

### Time Comparison

**Without persistent /nix:**
- Install NixOS: 5 min
- Download all packages: 20-30 min
- Configure: 5 min
- **Total: ~40 min**

**With persistent /nix (this setup):**
- Install NixOS: 5 min
- Apply config: 2 min (no downloads!)
- **Total: ~7 min**

## Advanced: Multiple Volumes

You could use multiple volumes for better organization:

```nix
# Volume 1: User data
fileSystems."/home" = {
  device = "/dev/disk/by-id/scsi-0HC_Volume_1";
  fsType = "ext4";
};

# Volume 2: Nix store (large, can be separate)
fileSystems."/nix" = {
  device = "/dev/disk/by-id/scsi-0HC_Volume_2";
  fsType = "ext4";
};
```

**Benefits:**
- Separate data from packages
- Can resize independently
- Can snapshot separately

## Backup Strategy

Even with persistent volumes, you should backup:

```bash
# Backup critical data
rsync -avz /home/qwe/ backup-server:/backups/qwe/

# Backup configuration (already in Git)
cd /etc/nixos && git push

# Backup Nix packages list (for reference)
nix-store --query --requisites /run/current-system > system-packages.txt
```

## Common Questions

### Q: Can I move the volume to a different cloud provider?

**A:** Not directly (Hetzner-specific), but you can:
1. Create volume in new provider
2. `rsync` data from Hetzner volume to new volume
3. Apply same NixOS configuration

### Q: What if I change the volume device path?

**A:** Just update `configuration.nix`:
```nix
fileSystems."/home".device = "/dev/disk/by-id/NEW-VOLUME-ID";
```
Then `nixos-rebuild switch`.

### Q: Do I need to backup the Nix store?

**A:** No! The Nix store is reproducible. You only need:
- Configuration files (in Git)
- User data (on volume)

Packages can be rebuilt/redownloaded from configuration.

### Q: What about secrets (API keys, passwords)?

**A:** Store them on the volume in `/home/qwe/.secrets/` or use [sops-nix](https://github.com/Mic92/sops-nix) for encrypted secrets in Git.

## Summary

Your current setup already provides excellent persistence:

| Data Type | Location | Persistent? | How |
|-----------|----------|-------------|-----|
| User files | `/home/qwe` | ✅ Yes | Volume mount |
| Nix packages | `/nix` | ✅ Yes | Bind mount to volume |
| Configuration | `/etc/nixos` | ✅ Yes | Git repository |
| System files | `/` | ❌ No | Rebuilt from config |

**You can safely destroy and recreate the VPS while keeping all data on the volume.**

The only thing you need to do on a new VPS:
1. Clone your Git repo
2. Run `nixos-rebuild switch`
3. Done!
