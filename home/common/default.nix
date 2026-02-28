{ config, pkgs, lib, ... }:
let
  # Declare Python packages that should be available in the global python
  # https://nixos.wiki/wiki/Python
  python-packages = ps: with ps; [
    requests
    uv
    virtualenv
    yt-dlp
  ];
in
{

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

  # TODO unsure if this is working
  home.sessionPath = [
    # Claude Code, etc., rely on this being on the path
    "~/.local/bin"
  ];

  home.packages = with pkgs; [
    awscli2

    # diff tools
    delta
    diff-so-fancy
    dyff

    devenv

    # better find commmand - search for files matching a name
    fd

    jq
    yq

    # Installs Python, and the defined packages
    (python3.withPackages python-packages)

    # Simple DNS client
    q

    # rg - Search for strings in files
    ripgrep

    # data parsing, in testing
    miller

    tldr

    wget
  ];

  # Permit non-free software
  nixpkgs.config.allowUnfree = true;

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;

  programs = {
    direnv = {
      enable = true;
      enableZshIntegration = true;
      nix-direnv.enable = true;
    };

    zsh.enable = true;
  };

  # https://nix.catppuccin.com/options/home-manager-options.html
  catppuccin = {
    # Enable catppuccin themes whereever supported
    enable = true;
    flavor = "macchiato";
  };
}
