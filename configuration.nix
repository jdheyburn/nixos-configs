{ config, pkgs, lib, ... }:
{

  nixpkgs.config.allowUnfree = true;
  
  # All imports

  # NixOS wants to enable GRUB by default
  boot.loader.grub.enable = false;

  system.stateVersion = "22.05"; 

  # if you have a Raspberry Pi 2 or 3, pick this:
  boot.kernelPackages = pkgs.linuxPackages_latest;

  # A bunch of boot parameters needed for optimal runtime on RPi 3b+
  boot.kernelParams = ["cma=256M"];
  boot.loader.raspberryPi.enable = true;
  boot.loader.raspberryPi.version = 3;
  boot.loader.raspberryPi.uboot.enable = true;
  boot.loader.raspberryPi.firmwareConfig = ''
    gpu_mem=256
  '';

  environment.systemPackages = with pkgs; [
    libraspberrypi

    # Packages I've added
    vim
    git
    tmux
    tldr
    restic
    rclone
    jq
    htop
    fzf
    python39
    kid3
  ];

  # File systems configuration for using the installer's partition layout
  fileSystems = {
    "/" = {
      device = "/dev/disk/by-label/NIXOS_SD";
      fsType = "ext4";
    };

    "/mnt/usb" = {
      device = "/dev/disk/by-uuid/D28E73C08E739BA3";
      fsType = "ntfs";
    };

  };

  # Preserve space by sacrificing documentation and history documentation.nixos.enable = false
  nix.gc.automatic = true;
  nix.gc.options = "--delete-older-than 30d";
  boot.cleanTmpDir = true;

  # Configure basic SSH access
  services.openssh = {
    enable = true;
    permitRootLogin = "no";
    passwordAuthentication = false;
  };

  # Use 1GB of additional swap memory in order to not run out of memory
  # when installing lots of things while running other things at the same time.
  swapDevices = [ { device = "/swapfile"; size = 2048; } ];

  # All my stuff now

  networking = {
    hostName = "dee";
    #domain = "joannet.casa";
    #useDHCP = false;

   #interfaces.eth0.ipv4.addresses = [ {
   #  address = "192.168.1.10";
   #  prefixLength = 24;
   #} ];
   #defaultGateway = "192.168.1.1";
   #nameservers = [
   #  "192.168.1.10"
   #  "1.1.1.1"
   #];

   firewall = {
     allowedTCPPorts = [
       2049 # NFS
       111 # NFS
       80 # Caddy
       443 # Caddy
       53 # DNS server
     ];
     allowedUDPPorts = [ 
       53 # DNS server
       111 # NFS
       2049 # NFS
     ];
   };
  };

  time.timeZone = "Europe/London";

  users.mutableUsers = false;
  users.users.jdheyburn = {
    isNormalUser = true;
    home = "/home/jdheyburn";
    extraGroups = [ "wheel" "networkmanager" ];
    hashedPassword = "$6$gFv39xwgs6Trun89$0uSAiTKWURlFUk5w4NoxmZXWlCKRamWYbTFdta7LSW1svzAUeuR3FGH2jX4UIcOaaMlLBJfqWLPUXKx1P1gch0";


    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIj0aUriXCgY/wNnYMvGoXajOqAr3EXdu7AeGA23s8ZG"
    ];
  };

  services.nfs.server.enable = true;
  # couldn't get 1.25 to work on macos, leaving here so i can see what did and didn't work
  services.nfs.server.exports = ''
    /mnt/usb 192.168.1.20(rw,nohide,insecure) 192.168.1.25(rw,nohide,insecure,no_subtree_check,all_squash,anonuid=1001,anongid=1001) 192.168.1.26(rw,nohide,insecure)
  '';

  services.samba = {
    enable = false;
    openFirewall = true;
    shares = { usb = {
      path = "/mnt/usb";
      writeable = "yes";
      "force user" = "root";
      "force group" = "root";
      "guest ok" = "yes";
    }; };
    extraConfig = ''
      hosts allow = 192.168.1.20 192.168.1.25 192.168.1.25 localhost
      hosts deny = 0.0.0.0/0
    '';
  };



  services.restic.backups = {
    media = {
      repository = "/mnt/usb/Backup/restic/media";
      passwordFile = "/etc/nixos/secrets/restic-media-password";
      pruneOpts = [
        "--keep-daily 30"
        "--keep-weekly 0"
        "--keep-monthly 0"
        "--keep-yearly 0"
      ];
      paths = [
        "/mnt/usb/Backup/media/beets-db"
        "/mnt/usb/Backup/media/lossless"
        "/mnt/usb/Backup/media/music"
        "/mnt/usb/Backup/media/vinyl"
      ];
      timerConfig = {
        OnCalendar = "*-*-* 02:00:00";
      };
    };
    small-files = {
      repository = "/mnt/usb/Backup/restic/small-files";
      passwordFile = "/etc/nixos/secrets/restic-small-files-password";
      pruneOpts = [
        "--keep-daily 7"
        "--keep-weekly 5"
        "--keep-monthly 12"
        "--keep-yearly 3"
      ];
      paths = [
        "/var/lib/unifi/data/backup/autobackup"
        "/var/lib/AdGuardHome/"
        "/var/lib/private/AdGuardHome"
      ];
      timerConfig = {
        OnCalendar = "*-*-* 02:00:00";
      };
    };
  };

  systemd.services.rclone-media = {
    # TODO can I refer to this from output of services.restic.backups.media ?
    wantedBy = [ "restic-backups-media.service" ];
    after = [ "restic-backups-media.service" ];
    environment = {
      RCLONE_CONFIG = "/etc/nixos/secrets/rclone.conf";
      RCLONE = "${pkgs.rclone}/bin/rclone";
      BACKUP_TYPE = "media";
    };
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.bash}/bin/bash /home/jdheyburn/dotfiles/restic/rclone-all.sh";
    };
  };
  systemd.services.rclone-small-files = {
    wantedBy = [ "restic-backups-small-files.service" ];
    after = [ "restic-backups-small-files.service" ];
    environment = {
      RCLONE_CONFIG = "/etc/nixos/secrets/rclone.conf";
      RCLONE = "${pkgs.rclone}/bin/rclone";
      BACKUP_TYPE = "small-files";
    };
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.bash}/bin/bash /home/jdheyburn/dotfiles/restic/rclone-all.sh";
    };
  };
  
  services.unifi = {
    enable = true;
    unifiPackage = pkgs.unifiStable;
    maximumJavaHeapSize = 256;
    jrePackage = pkgs.jre8_headless;
    # TODO explore if this can be closed, if Caddy reverse proxies enough
    # Port 8443 does not need to be open because caddy proxies 443 -> 8443
    # But other ports may need to be open for unifi operations
    openFirewall = true;
  };

  services.caddy = {
    enable = true;
    package = (pkgs.callPackage ./custom-caddy.nix {
      plugins = [ "github.com/caddy-dns/cloudflare" ];
      vendorSha256 = "sha256-HrUARAM0/apr+ijSousglLYgxVNy9SFW6MhWkSeTFU4=";
    });
    extraConfig = ''
      unifi.svc.joannet.casa {
        tls {
          dns cloudflare {env.CLOUDFLARE_API_TOKEN}
        }
       
        reverse_proxy localhost:8443 {
          transport http {
            tls_insecure_skip_verify
          }
        }
      }
      adguard.svc.joannet.casa {
        tls {
          dns cloudflare {env.CLOUDFLARE_API_TOKEN}
        }
       
        reverse_proxy localhost:3000
      }
    '';
  };
  systemd.services.caddy = {
    environment = {
      CLOUDFLARE_API_TOKEN = "REDACTED";
    };

    serviceConfig = {
      # Required to use ports < 1024
      AmbientCapabilities = "cap_net_bind_service";
      CapabilityBoundingSet = "cap_net_bind_service";
    };
  };

  services.adguardhome = {
    enable = true;
  };

  # Attempted remote builds (blocked on matching system / platform, I don't have an aarch64-linux machine)
  nix.buildMachines = [{
    hostName = "buildervm";
    systems = [ "aarch64-linux" ];
    maxJobs = 1;
    speedFactor = 2;
    mandatoryFeatures = [];
  }];
  nix.distributedBuilds = true;
  nix.extraOptions = ''
    builders-use-substitutes = true
  '';

}

