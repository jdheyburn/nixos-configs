{ config, pkgs, lib, ... }: {

  imports = [ ./hardware-configuration.nix ];

  ###############################################################################
  ## General
  ###############################################################################

  networking.hostName = "dee";
  networking.hostId = "5468c04f";

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "22.05";

  #############################################################################
  ## Package management
  #############################################################################

  environment.systemPackages = with pkgs; [
    atop
    libraspberrypi
    iotop
    smartmontools
    kid3
    python39
    restic
    sysstat
  ];

  #############################################################################
  ## Modules
  #############################################################################


  age.secrets."restic-small-files-password".file =
    ../../secrets/restic-small-files-password.age;

  age.secrets."rclone.conf".file = ../../secrets/rclone.conf.age;

  modules.backupSF = {
    enable = false;
    passwordFile = config.age.secrets."restic-small-files-password".path;
    paths = [
      "/var/lib/unifi/data/backup/autobackup"
      "/var/lib/AdGuardHome/"
      "/var/lib/private/AdGuardHome"
    ];
    backupTime = "*-*-* 02:10:00";
  };

  modules.backupUSB.enable = false;
  modules.caddy.enable = true;
  modules.dns.enable = true;
  modules.monitoring.enable = true;
  modules.nfs.enable = false;
  modules.plex.enable = true;
  modules.unifi.enable = true;

  # Attempted remote builds (blocked on matching system / platform, I don't have an aarch64-linux machine)
  # nix.buildMachines = [{
  #   hostName = "buildervm";
  #   systems = [ "aarch64-linux" ];
  #   maxJobs = 1;
  #   speedFactor = 2;
  #   mandatoryFeatures = [];
  # }];
  # nix.distributedBuilds = true;
  # nix.extraOptions = ''
  #   builders-use-substitutes = true
  # '';
}

