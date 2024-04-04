{ config, lib, pkgs, flake-self, ... }:

{
  config = {
    #############################################################################
    ## General
    #############################################################################

    # The NixOS release to be compatible with for stateful data such as databases.
    # Pi uses 21.05
    # system.stateVersion = "21.11";

    boot.tmp.cleanOnBoot = true;

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
      settings = {
        PermitRootLogin = "no";
        PasswordAuthentication = false;
        KbdInteractiveAuthentication = false;
      };
    };

    # Start ssh-agent as a systemd user service
    programs.ssh.startAgent = true;

    services.tailscale.enable = true;
    # Tailscale wants this setting for: "Strict reverse path filtering breaks Tailscale exit node use and some subnet routing setups"
    # If making tailscale optional in future, consider conditionally setting below if enabled
    networking.firewall.checkReversePath = "loose";

    # Rotate logs to prevent them getting too big
    services.logrotate.enable = true;

    #############################################################################
    ## User accounts
    #############################################################################

    # Set zsh as the default shell
    environment.shells = with pkgs; [ zsh ];
    programs.zsh.enable = true;
    users.defaultUserShell = pkgs.zsh;

    # Now for user stuff
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
        # Not sure what below is for
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIj0aUriXCgY/wNnYMvGoXajOqAr3EXdu7AeGA23s8ZG"
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMmocucDbkSd6A2xCE4JTQXDZSuOQH3p3c9khu1/0LIe jdheyburn@paddys.joannet.casa"
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILe14GNyaLe1K09LMSdj1RuD3U6HHSJAZ7rBF40N2C6m jdheyburn@dee"
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIC0kg1FOtTN0y3Dpigb6OyPiMtvcPHTfWJXLeO6yyzUp jdheyburn@dennis"
      ];
    };

    # To allow for deploy-rs  
    security.sudo.extraRules = [{
      users = [ "jdheyburn" ];
      commands = [{
        command = "ALL";
        options = [ "NOPASSWD" ];
      }];
    }];
    nix.settings.trusted-users = [ "jdheyburn" ];

    #############################################################################
    ## Package management
    #############################################################################

    # Preserve space by gc-ing and optimising store
    nix.gc.automatic = true;
    nix.gc.options = "--delete-older-than 30d";
    nix.settings.auto-optimise-store = true;

    # Enable flakes
    nix.package = pkgs.nixVersions.stable;
    nix.extraOptions = ''
      experimental-features = nix-command flakes
    '';

    # Allow packages with non-free licenses.
    nixpkgs.config.allowUnfree = true;
    # Given we're using unfree, let's use numtide's cachix which should have cached binaries of some unfree packages
    # Nix Hydra doesn't build unfree packages
    nix.settings.substituters = [ "https://numtide.cachix.org" ];
    nix.settings.trusted-public-keys =
      [ "numtide.cachix.org-1:2ps1kLBUWjxIneOy1Ik6cQjb41X0iXVXeHigGmycPPE=" ];

    nixpkgs.overlays = [ flake-self.overlays.default ];

    # System-wide packages
    ## TODO there are packages here which should be shared with home-manager
    ## to allow macbook to get them too
    environment.systemPackages = with pkgs; [
      bind # Gets dig
      # busybox # Gets nslookup - but disabled since reboot was clashing with systemd, use q instead
      fd # better find commmand - search for files matching a name
      git
      htop
      jq
      ncdu
      python3
      q # nice simple DNS client
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
