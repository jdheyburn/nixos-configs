{ config, lib, pkgs, ... }:

{
  config = {
    #############################################################################
    ## General
    #############################################################################

    # The NixOS release to be compatible with for stateful data such as databases.
    # Pi uses 21.05
    # system.stateVersion = "21.11";

    boot.cleanTmpDir = true;

    networking.domain = "joannet.casa";

    #############################################################################
    ## Locale
    #############################################################################

    # Locale
    i18n.defaultLocale = "en_GB.UTF-8";

    # Timezone
    services.timesyncd.enable = true;
    time.timeZone = "Europe/London";

    # Keyboard
    console.keyMap = "uk";
    services.xserver.layout = "gb";

    #############################################################################
    ## Services
    #############################################################################

    services.openssh = {
      enable = true;
      permitRootLogin = "no";
      passwordAuthentication = false;
      kbdInteractiveAuthentication = false;
    };

    # Start ssh-agent as a systemd user service
    programs.ssh.startAgent = true;

    services.tailscale.enable = true;

    #############################################################################
    ## User accounts
    #############################################################################

    users.defaultUserShell = pkgs.zsh;
    users.mutableUsers = false;
    users.users.jdheyburn = {
      uid = 1000;
      description = "Joseph Heyburn";
      isNormalUser = true;
      home = "/home/jdheyburn";
      extraGroups = [ "wheel" "networkmanager" ];
      hashedPassword =
        "$6$gFv39xwgs6Trun89$0uSAiTKWURlFUk5w4NoxmZXWlCKRamWYbTFdta7LSW1svzAUeuR3FGH2jX4UIcOaaMlLBJfqWLPUXKx1P1gch0";

      openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIj0aUriXCgY/wNnYMvGoXajOqAr3EXdu7AeGA23s8ZG"
      ];
    };

    #############################################################################
    ## Package management
    #############################################################################

    # Preserve space by gc-ing and optimising store
    nix.gc.automatic = true;
    nix.gc.options = "--delete-older-than 30d";
    nix.autoOptimiseStore = true;

    # Enable flakes
    nix.package = pkgs.nixFlakes;
    nix.extraOptions = ''
      experimental-features = nix-command flakes
    '';

    # Allow packages with non-free licenses.
    nixpkgs.config.allowUnfree = true;

    # System-wide packages
    environment.systemPackages = with pkgs; [
      bind # Gets dig
      # busybox # Gets nslookup - but disabled since reboot was clashing with systemd
      fzf
      git
      htop
      jq
      ncdu
      neovim # so that root can have it - TODO set in home-manager?
      nixfmt
      python3
      ranger
      rclone
      rsync
      tldr
      tmux
      unzip
      wget
    ];
  };

}
