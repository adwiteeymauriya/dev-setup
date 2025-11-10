# Migration Guide: Bash Script → NixOS Flake

## What Changed

### Before (Bash Script)
```bash
setup_dev.sh --init
# - Formats volume
# - Creates user
# - Installs Docker
# - Installs Nix, NVM, uv, Devbox manually
# - Configures shell with curl | bash installers
```

### After (NixOS Flake)
```bash
nixos-rebuild switch --flake .#devserver
# - Everything declarative
# - Reproducible
# - Rollback support
# - Atomic updates
```

## Feature Mapping

| Bash Script | NixOS Configuration | File |
|-------------|---------------------|------|
| User creation (useradd) | `users.users.qwe` | configuration.nix:46-54 |
| Volume mount | `fileSystems."/home"` | configuration.nix:22-26 |
| /nix bind mount | `fileSystems."/nix"` | configuration.nix:28-33 |
| Docker install | `virtualisation.docker.enable` | configuration.nix:66-69 |
| Passwordless sudo | `security.sudo.wheelNeedsPassword` | configuration.nix:59 |
| SSH setup | `services.openssh` | configuration.nix:61-66 |
| Devbox install | `home.packages = [ devbox ]` | home.nix:13 |
| NVM + Node | `nodejs_22` | home.nix:15-18 |
| uv install | `uv` | home.nix:21-22 |
| Zsh config | `programs.zsh` | home.nix:37-57 |

## Migration Steps

### Option 1: Clean Install (Recommended)

1. **Backup data** from existing server
2. **Destroy** the Hetzner instance (keep the volume!)
3. **Create new instance** with NixOS image
4. **Attach volume** to new instance
5. **Format volume** (if needed): `mkfs.ext4 /dev/disk/by-id/scsi-0HC_Volume_103912881`
6. **Clone config**: `git clone <repo> /etc/nixos && cd /etc/nixos`
7. **Apply**: `nixos-rebuild switch --flake .#devserver`

### Option 2: In-Place Conversion

Use [nixos-infect](https://github.com/elitak/nixos-infect) to convert Debian/Ubuntu to NixOS:

```bash
# On your existing Debian/Ubuntu server
curl https://raw.githubusercontent.com/elitak/nixos-infect/master/nixos-infect | \
  NIX_CHANNEL=nixos-unstable bash

# After reboot, the system will be running NixOS
# Clone configuration
git clone <repo> /etc/nixos && cd /etc/nixos

# Generate hardware config
nixos-generate-config --show-hardware-config > hardware-configuration.nix

# Apply the configuration
nixos-rebuild switch --flake .#devserver
```

### Option 3: Test in VM First

```bash
# On your local machine with NixOS or Nix installed
nix run nixpkgs#nixos-rebuild -- build-vm --flake .#devserver

# This creates a QEMU VM to test your configuration
./result/bin/run-nixos-vm
```

## What Gets Better

### 1. Updates
**Before:**
```bash
# Manual updates, hope nothing breaks
curl -L https://new-version.com | bash
```

**After:**
```nix
# Change version in flake.nix or configuration
home.packages = [ pkgs.neovim ];  # Always gets latest from nixpkgs
```

### 2. Rollback
**Before:**
```bash
# Something broke? Good luck! 🤷
# Restore from backup or reinstall
```

**After:**
```bash
# Something broke? No problem!
nixos-rebuild switch --rollback
# System restored in seconds
```

### 3. Reproducibility
**Before:**
```bash
# "Works on my machine"
# Different versions over time
# Drift between servers
```

**After:**
```bash
# Exact same environment everywhere
# Pin package versions
# Share configuration via Git
```

### 4. Testing
**Before:**
```bash
# Test in production and pray 🙏
```

**After:**
```bash
# Test in VM before applying
nix run nixpkgs#nixos-rebuild -- build-vm --flake .#devserver
```

### 5. Documentation
**Before:**
```bash
# Comments in bash script (if you're lucky)
# Mental model of what's installed
```

**After:**
```nix
# Configuration IS the documentation
# Every package explicitly declared
# Easy to see what's installed: nix-env -q
```

## Removed Complexity

### No More:
- ❌ Multiple `sudo -u` calls
- ❌ `curl | bash` installers
- ❌ Manual PATH management
- ❌ Shell rc file modifications
- ❌ Checking if tools are already installed
- ❌ Different code paths for --init vs --attach
- ❌ `.dev_tools_installed` marker files

### Replaced With:
- ✅ Single declarative configuration
- ✅ Automatic dependency resolution
- ✅ Built-in idempotency
- ✅ Atomic updates
- ✅ Rollback support

## Cost Comparison

### Bash Script Maintenance
- Every update needs testing
- Different behavior over time
- Hard to replicate issues
- Manual tracking of installed tools
- Version drift between runs

### NixOS Maintenance
- Updates are declarative
- Behavior is consistent
- Easy to replicate (just apply flake)
- Configuration shows everything
- No drift (reproducible builds)

## Real-World Scenarios

### Scenario 1: Add a new tool

**Bash:**
```bash
# Edit setup_dev.sh
sudo -u qwe bash -c 'curl https://install-tool.sh | bash'
# Test on server
# Hope it works
```

**NixOS:**
```nix
# Edit home.nix
home.packages = [ pkgs.new-tool ];
# Test locally or in VM
# Apply: nixos-rebuild switch --flake .#devserver
```

### Scenario 2: Something broke

**Bash:**
```bash
# No idea what changed
# Check history?
# Restore from backup
# Or reinstall everything
```

**NixOS:**
```bash
# List changes
nixos-rebuild list-generations

# Rollback to working state
nixos-rebuild switch --rollback

# Or switch to specific generation
nixos-rebuild switch --switch-generation 42
```

### Scenario 3: Clone environment to new server

**Bash:**
```bash
# Run setup_dev.sh again
# Different versions of tools
# Slightly different behavior
# Debug differences
```

**NixOS:**
```bash
# Clone git repo
# Apply flake
nixos-rebuild switch --flake .#devserver
# Identical environment ✨
```

### Scenario 4: Update Node.js

**Bash:**
```bash
nvm install 23
nvm alias default 23
# Hope nothing breaks
```

**NixOS:**
```nix
# Change nodejs_22 to nodejs_23
home.packages = [ pkgs.nodejs_23 ];
# Test in VM first
# Apply when ready
# Easy rollback if needed
```

## Benefits Summary

| Aspect | Bash Script | NixOS Flake |
|--------|-------------|-------------|
| Setup time | ~10 min | ~5 min (after NixOS installed) |
| Reproducibility | Low | 100% |
| Rollback | No | Yes (instant) |
| Version control | Script only | Everything |
| Testing | Production | VM before production |
| Updates | Manual | Declarative |
| Documentation | External | Self-documenting |
| Drift prevention | No | Yes |
| Multi-server | Inconsistent | Identical |

## Potential Challenges

### Learning Curve
- Nix language is different
- Need to understand Nix concepts
- Documentation can be sparse

**Mitigation:**
- Start with provided configuration
- Make small changes
- Test in VM
- Use [search.nixos.org](https://search.nixos.org) for packages

### Initial Setup
- Need to install NixOS first
- More complex initial bootstrap

**Mitigation:**
- Use nixos-infect for easy conversion
- Or use provided install.sh script
- One-time cost, long-term benefit

### Binary Cache
- First build can be slow
- Need good internet connection

**Mitigation:**
- NixOS has excellent binary caches
- Most packages are pre-built
- Only custom configs need building

## Conclusion

The NixOS flake approach is objectively better for:
- ✅ Long-term maintenance
- ✅ Multiple servers
- ✅ Team environments
- ✅ Production reliability
- ✅ Disaster recovery

The bash script is simpler for:
- ❌ One-off setups
- ❌ No NixOS knowledge
- ❌ Quick prototypes

**Recommendation:** Invest in NixOS. The upfront cost pays dividends in reliability, reproducibility, and peace of mind.
