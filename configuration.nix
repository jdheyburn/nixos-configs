{ config, pkgs, lib, ... }:
{

  # All imports

  # NixOS wants to enable GRUB by default
  boot.loader.grub.enable = false;

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
  swapDevices = [ { device = "/swapfile"; size = 1024; } ];

  # All my stuff now

  networking.hostName = "dee";
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
  services.nfs.server.exports = ''
    /mnt/usb 192.168.2.69(rw,nohide,insecure) 192.168.2.10(rw,nohide,insecure)
  '';
  networking.firewall.allowedTCPPorts = [ 2049 ];


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
  };

  systemd.services.rclone-all = {
    # TODO can I refer to this from output of services.restic.backups.media ?
    wantedBy = [ "restic-backups-media.service" ];
    after = [ "restic-backups-media.service" ];
    environment = {
      RCLONE_CONFIG_DIR = "/etc/nixos/secrets";
      RCLONE = "${pkgs.rclone}/bin/rclone";
    };
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.bash}/bin/bash /home/jdheyburn/dotfiles/restic/rclone-all.sh";
    };
  };
}

