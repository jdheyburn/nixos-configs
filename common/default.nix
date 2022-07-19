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

    services.fail2ban = { enable = true; };

    services.openssh = {
      enable = true;
      permitRootLogin = "no";
      passwordAuthentication = false;
      kbdInteractiveAuthentication = false;
    };

    # Start ssh-agent as a systemd user service
    programs.ssh.startAgent = true;

    services.tailscale.enable = true;
    # Tailscale wants this setting for: "Strict reverse path filtering breaks Tailscale exit node use and some subnet routing setups"
    # If making tailscale optional in future, consider conditionally setting below if enabled
    networking.firewall.checkReversePath = "loose";

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
      extraGroups = [ "networkmanager" "wheel" ];
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
    nix.gc.automatic = false;
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
      exa # posh ls
      # busybox # Gets nslookup - but disabled since reboot was clashing with systemd
      fd # better find commmand - search for files matching a name
      git
      htop
      jq
      ncdu
      nixfmt
      python3
      ranger
      rclone
      ripgrep # silver-searcher but newer
      rsync
      silver-searcher # exposes ag - used to search strings in files
      sysstat # collection of perf mon tools for linux
      tldr
      unzip
      wget

      powertop
    ];
  };

}