{ config, pkgs, ... }:

{
  # ========= HOME MANAGER CONFIGURATION =========

  home.stateVersion = "24.05";
  home.username = "qwe";
  home.homeDirectory = "/home/qwe";

  # ========= DEVELOPMENT PACKAGES =========

  home.packages = with pkgs; [
    # Development tools
    devbox
    git

    # Node.js ecosystem
    nodejs_22
    nodePackages.npm
    nodePackages.pnpm
    nodePackages.yarn

    # Python
    python312
    uv

    # Build essentials
    gcc
    gnumake
    pkg-config

    # CLI tools
    ripgrep
    fd
    bat
    eza
    fzf
    jq
  ];

  # ========= SHELL CONFIGURATION =========

  programs.zsh = {
    enable = true;
    enableCompletion = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;
    histSize = 10000;

    shellAliases = {
      ll = "eza -la";
      ls = "eza";
      cat = "bat";
      grep = "rg";
    };

    initExtra = ''
      # Custom prompt or starship
      eval "$(starship init zsh)"
    '';

    oh-my-zsh = {
      enable = true;
      plugins = [ "git" "docker" "npm" "python" ];
      theme = "robbyrussell";
    };
  };

  users.defaultUserShell = pkgs.zsh;
  environment.shells = pkgs.zsh;
  # ========= GIT =========

  programs.git = {
    enable = true;
    userName = "qwe";
    userEmail = "qwe@example.com";
    extraConfig = {
      init.defaultBranch = "main";
      pull.rebase = true;
    };
  };

  # ========= STARSHIP PROMPT =========

  programs.starship = {
    enable = true;
    settings = {
      add_newline = false;
      format = "$directory$git_branch$git_status$character";
      character = {
        success_symbol = "[➜](bold green)";
        error_symbol = "[➜](bold red)";
      };
    };
  };

  # ========= TMUX =========

  programs.tmux = {
    enable = true;
    clock24 = true;
    keyMode = "vi";
    terminal = "screen-256color";
    extraConfig = ''
      set -g mouse on
      set -g status-style bg=black,fg=white
    '';
  };

  # ========= DIRENV (for project-specific environments) =========

  programs.direnv = {
    enable = true;
    enableZshIntegration = true;
    nix-direnv.enable = true;
  };

  # ========= SESSION VARIABLES =========

  home.sessionVariables = {
    EDITOR = "vim";
    VISUAL = "vim";
  };

  # Let Home Manager manage itself
  programs.home-manager.enable = true;
}
