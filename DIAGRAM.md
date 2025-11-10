# Visual Architecture Diagram

## Storage Layout

```
┌─────────────────────────────────────────────────────────────────┐
│                         Hetzner VPS                             │
│                                                                 │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  Root Disk (Ephemeral - rebuilt each time)              │  │
│  │                                                          │  │
│  │  /                                                       │  │
│  │  ├── boot/                                               │  │
│  │  ├── etc/                                                │  │
│  │  │   └── nixos/  ← Configuration (from Git)             │  │
│  │  │       ├── flake.nix                                   │  │
│  │  │       ├── configuration.nix                           │  │
│  │  │       └── home.nix                                    │  │
│  │  │                                                        │  │
│  │  ├── run/                                                 │  │
│  │  └── var/                                                 │  │
│  │                                                          │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                 │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  Mounted from Volume (Persistent - survives VPS changes) │  │
│  │                                                          │  │
│  │  /home/  ← Mounted from volume                          │  │
│  │  └── qwe/                                                │  │
│  │      ├── .ssh/         ← SSH keys                        │  │
│  │      ├── projects/     ← Your code                       │  │
│  │      ├── .config/      ← Config files                    │  │
│  │      ├── docker/       ← Docker data (optional)          │  │
│  │      └── nix/          ← Nix store (bind mounted)        │  │
│  │          └── store/    ← All packages                    │  │
│  │                                                          │  │
│  └──────────────────────────────────────────────────────────┘  │
│                     ↑                                           │
│                     │ Bind mount                                │
│                     ↓                                           │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  /nix/  ← Bind mounted to /home/qwe/nix                 │  │
│  │  └── store/                                              │  │
│  │      ├── abc123-nodejs/                                  │  │
│  │      ├── def456-python/                                  │  │
│  │      └── ghi789-docker/                                  │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
                              ↑
                              │
                              │ Attached to VPS
                              │
┌─────────────────────────────┴───────────────────────────────────┐
│                    Hetzner Volume                               │
│                  (Persistent Block Storage)                     │
│                                                                 │
│  /dev/disk/by-id/scsi-0HC_Volume_103912881                     │
│                                                                 │
│  ┌─────────────────────────────────────────────────────────┐  │
│  │  Volume Contents (survives VPS destruction)             │  │
│  │                                                          │  │
│  │  qwe/                                                    │  │
│  │  ├── .ssh/                                               │  │
│  │  ├── projects/                                           │  │
│  │  ├── .config/                                            │  │
│  │  ├── docker/                                             │  │
│  │  └── nix/                                                │  │
│  │      └── store/  ← All Nix packages                      │  │
│  │                                                          │  │
│  └─────────────────────────────────────────────────────────┘  │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

## Data Flow During VPS Recreation

```
Step 1: Old VPS Running
┌──────────────┐
│   Old VPS    │
│              │
│   /home ─────┼────► Volume (Data Safe)
│   /nix  ─────┼────► Volume (Packages Safe)
└──────────────┘

Step 2: Destroy Old VPS
┌──────────────┐
│  DESTROYED   │       Volume (Data Still Safe!)
└──────────────┘      ┌───────────────┐
                      │  qwe/         │
                      │  ├── .ssh/    │
                      │  ├── projects/│
                      │  └── nix/     │
                      └───────────────┘

Step 3: Create New VPS
┌──────────────┐      ┌───────────────┐
│   New VPS    │      │  Volume       │
│   (Fresh)    │      │  (Unchanged)  │
└──────────────┘      └───────────────┘

Step 4: Attach Volume
┌──────────────┐
│   New VPS    │
│              │◄─────  Attach Volume
└──────────────┘

Step 5: Apply NixOS Config
┌──────────────┐
│   New VPS    │
│              │
│ 1. Mount /home from volume
│ 2. Bind /nix to /home/qwe/nix
│ 3. Create user qwe (UID 1000)
│ 4. Apply home-manager
│ 5. Start services
│              │
│ FULLY RESTORED!
└──────────────┘
```

## File System Hierarchy

```
/
├── boot/                    [Ephemeral - VPS root disk]
├── etc/
│   └── nixos/              [Ephemeral - but in Git]
│       ├── flake.nix
│       ├── configuration.nix
│       └── home.nix
├── home/                    [Persistent - Volume mount]
│   └── qwe/                 ↓
│       ├── .ssh/            Survives VPS changes
│       ├── .config/         ↓
│       ├── projects/
│       └── nix/
│           └── store/
└── nix/                     [Persistent - Bind mount]
    └── store/               Linked to /home/qwe/nix/store
        ├── a1b2c3-bash-5.2/
        ├── d4e5f6-nodejs-22.0/
        └── g7h8i9-docker-25.0/

Legend:
├── [Ephemeral]  Rebuilt from configuration
└── [Persistent] Survives on volume
```

## Network Architecture

```
                    Internet
                       │
                       ↓
              ┌────────────────┐
              │  Hetzner Cloud │
              └────────┬───────┘
                       │
        ┌──────────────┼──────────────┐
        │              │              │
        ↓              ↓              ↓
   ┌────────┐    ┌────────┐    ┌────────┐
   │ VPS #1 │    │ VPS #2 │    │ VPS #3 │
   └────┬───┘    └───┬────┘    └───┬────┘
        │            │              │
        │            │              │
   ┌────┴─────┐ ┌───┴──────┐  ┌───┴──────┐
   │ Volume A │ │ Volume B │  │ Volume C │
   └──────────┘ └──────────┘  └──────────┘

   Same config   Same config   Same config
   (/etc/nixos   (/etc/nixos   (/etc/nixos
    from Git)     from Git)     from Git)

   = Identical environments across all VPSs!
```

## Update Flow

```
Developer Machine              Git Remote              VPS
┌───────────────┐             ┌─────────┐       ┌─────────────┐
│ Edit configs  │             │ GitHub  │       │   Hetzner   │
│               │             │         │       │             │
│ ├─ flake.nix  │   git push  │         │       │             │
│ └─ home.nix   ├────────────►│ Config  │       │             │
│               │             │  Repo   │       │             │
└───────────────┘             └────┬────┘       └──────┬──────┘
                                   │                   │
                                   │   git pull        │
                                   └──────────────────►│
                                                       │
                                         nixos-rebuild │
                                                switch │
                                                       │
                                              Applied! │
                                                       ▼
                                             New generation
```

## Rollback Flow

```
Current State (Generation 42)
┌────────────────────────────┐
│  Something broke!          │
│  System not working        │
└────────────────────────────┘
              │
              │ nixos-rebuild switch --rollback
              ↓
Previous State (Generation 41)
┌────────────────────────────┐
│  System restored!          │
│  Working again             │
│                            │
│  Time: < 5 seconds         │
└────────────────────────────┘
```

## Comparison: Bash Script vs NixOS

```
Bash Script Approach                NixOS Flake Approach
───────────────────────────         ────────────────────────

Manual steps                        Declarative config
  ↓                                   ↓
curl | bash installers              Pure Nix packages
  ↓                                   ↓
Check if installed                  Always idempotent
  ↓                                   ↓
Multiple sudo -u calls              Single configuration
  ↓                                   ↓
Hope nothing breaks                 Atomic updates
  ↓                                   ↓
No rollback                         Instant rollback
  ↓                                   ↓
Configuration drift                 Always reproducible
  ↓                                   ↓
Hard to replicate                   Clone & apply
  ↓                                   ↓
❌ Different every time             ✅ Identical always
```

## Three-Tier Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    Configuration                        │
│                  (Version Controlled)                   │
│                                                         │
│  Git Repository                                         │
│  ├── flake.nix       ← Inputs & system definition      │
│  ├── configuration.nix ← System config                 │
│  └── home.nix        ← User environment                 │
└────────────────────────┬────────────────────────────────┘
                         │
                         │ nixos-rebuild switch
                         ↓
┌─────────────────────────────────────────────────────────┐
│                   System State                          │
│                  (Ephemeral - VPS)                      │
│                                                         │
│  /                                                      │
│  ├── System files    ← Rebuilt from config             │
│  ├── Services        ← Defined in config               │
│  └── /etc/nixos      ← Config files (from Git)         │
└────────────────────────┬────────────────────────────────┘
                         │
                         │ Mounts
                         ↓
┌─────────────────────────────────────────────────────────┐
│                   Persistent Data                       │
│                  (Volume Storage)                       │
│                                                         │
│  Hetzner Volume                                         │
│  ├── /home/qwe       ← User files                      │
│  └── /nix/store      ← Packages (bind mounted)         │
└─────────────────────────────────────────────────────────┘
```

## Key Insight

```
┌────────────────────────────────────────────────────────┐
│                                                        │
│   Configuration (Git) + Persistent Data (Volume)       │
│                        =                               │
│              Complete System State                     │
│                                                        │
│   VPS is just temporary compute!                       │
│                                                        │
└────────────────────────────────────────────────────────┘
```

You can destroy and recreate the VPS any time.
Your data and packages are safe on the volume.
Your configuration is safe in Git.
Just apply and you're back to work!
