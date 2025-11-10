{ config, pkgs, lib, ... }:

let
  machineSpecific = import ./machine-specific.nix;
in
{
  imports = [
    ./hardware-configuration.nix
    # Uncomment if you want to use nixos-infect generated networking
    # ./networking.nix
  ];

  # ========= SYSTEM CONFIGURATION =========

  system.stateVersion = "24.05";

  # Enable flakes
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # ========= BOOT & FILESYSTEM =========

  boot.loader.grub.enable = true;
  boot.loader.grub.device = machineSpecific.rootDevice;

  # Persistent volume mount
  fileSystems."/" = {
    device = machineSpecific.rootPartition;
    fsType = "ext4";
  };

  fileSystems."/home" = {
    device = machineSpecific.volumeDevice;
    fsType = "ext4";
    options = [ "discard" "defaults" ];
  };

  # NOTE: /nix stays on root disk (ephemeral)
  # This is simpler and avoids bootstrap complexity.
  # NixOS has excellent binary caches, so rebuilds are fast (~10-20 min).
  # If you want persistent /nix, see BOOTSTRAP.md for the process.

  # ========= NETWORKING =========

  networking.hostName = machineSpecific.hostname;
  networking.useDHCP = true;
  networking.firewall.enable = true;

  # ========= USERS =========

  users.users.qwe = {
    isNormalUser = true;
    home = "/home/qwe";
    uid = 1000;
    group = "qwe";
    shell = pkgs.zsh;
    extraGroups = [ "wheel" "docker" ];
    openssh.authorizedKeys.keyFiles = [ /root/.ssh/authorized_keys ];
  };

  users.groups.qwe = {
    gid = 1000;
  };

  # Passwordless sudo
  security.sudo.wheelNeedsPassword = false;

  # ========= SSH =========

  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "prohibit-password";
      PasswordAuthentication = false;
    };
  };

  # ========= DOCKER =========

  virtualisation.docker = {
    enable = false;
    autoPrune.enable = true;
    rootless = {
    enable = true;
    setSocketVariable = true; # Automatically sets DOCKER_HOST for users
  };
    # Store Docker data on persistent volume (uncomment to enable)
    # dataRoot = "/home/qwe/docker";
  };

  # ========= SYSTEM PACKAGES =========

  environment.systemPackages = with pkgs; [
    vim
    curl
    wget
    git
    unzip
    zip
    htop
    tmux
  ];

  # Enable zsh system-wide
  programs.zsh.enable = true;
}
