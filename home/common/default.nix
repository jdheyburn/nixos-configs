{ config, pkgs, lib, ... }: {

  imports = [
    ./cli
    ./git
    ./neovim
    ./tmux
    ./zsh
  ];

  # You can update Home Manager without changing this value. See
  # the Home Manager release notes for a list of state version
  # changes in each release.
  home.stateVersion = "22.05";

  home.packages = with pkgs; [
    awscli2
    
    delta
    diff-so-fancy
    dyff

    # better find commmand - search for files matching a name
    fd

    jq
    yq

    # Simple DNS client
    q

    # rg - Search for strings in files
    ripgrep

    # data parsing, in testing
    miller

    tldr

    wget
  ];

  # hyper.js styling
  home.file.".hyper.js" = {
    enable = true;
    source = ./hyper/hyper.js;
  };

  # Permit non-free software
  nixpkgs.config.allowUnfree = true;

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;

  # https://nix.catppuccin.com/options/home-manager-options.html
  catppuccin = {
    # Enable catppuccin themes whereever supported
    enable = true;
    flavor = "macchiato";
  };

}
