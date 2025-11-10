{ config, pkgs, lib, ... }:

{
  imports = [
    ./hardware-configuration.nix
  ];

  # ========= SYSTEM CONFIGURATION =========

  system.stateVersion = "24.05";

  # Enable flakes
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # ========= BOOT & FILESYSTEM =========

  boot.loader.grub.enable = true;
  boot.loader.grub.device = "/dev/sda";

  # Persistent volume mount
  fileSystems."/" = {
    device = "/dev/sda1";
    fsType = "ext4";
  };

  fileSystems."/home" = {
    device = "/dev/disk/by-id/scsi-0HC_Volume_103912881";
    fsType = "ext4";
    options = [ "discard" "defaults" ];
  };

  # Bind mount /nix to persistent storage
  fileSystems."/nix" = {
    device = "/home/qwe/nix";
    fsType = "none";
    options = [ "bind" ];
    depends = [ "/home" ];
  };

  # ========= NETWORKING =========

  networking.hostName = "devserver";
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
    enable = true;
    autoPrune.enable = true;
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
