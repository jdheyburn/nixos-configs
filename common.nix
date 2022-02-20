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
            permitRootLogin = "yes";
            # passwordAuthentication = false;
            # challengeResponseAuthentication = false;
        };

        # Start ssh-agent as a systemd user service
        programs.ssh.startAgent = true;

        #############################################################################
        ## User accounts
        #############################################################################

        users.mutableUsers = false;
        users.users.jdheyburn = {
            uid = 1000;
            description = "Joseph Heyburn";
            isNormalUser = true;
            home = "/home/jdheyburn";
            extraGroups = [ "wheel" "networkmanager" ];
            hashedPassword = "$6$gFv39xwgs6Trun89$0uSAiTKWURlFUk5w4NoxmZXWlCKRamWYbTFdta7LSW1svzAUeuR3FGH2jX4UIcOaaMlLBJfqWLPUXKx1P1gch0";


            openssh.authorizedKeys.keys = [
                "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIj0aUriXCgY/wNnYMvGoXajOqAr3EXdu7AeGA23s8ZG"
            ];
        };

        #############################################################################
        ## Package management
        #############################################################################

        # Preserve space by sacrificing documentation and history documentation.nixos.enable = false
        nix.gc.automatic = true;
        nix.gc.options = "--delete-older-than 30d";

        # Allow packages with non-free licenses.
        nixpkgs.config.allowUnfree = true;

        # System-wide packages
        environment.systemPackages = with pkgs; [
            fzf
            git
            htop
            jq
            ncdu
            python3
            rclone
            rsync
            tldr
            tmux
            unzip
            vim
            wget
        ];
    };

}
