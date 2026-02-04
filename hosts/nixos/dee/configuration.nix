{ argononed, catalog, config, pkgs, lib, myUtils, ... }: {

  imports = [ ./hardware-configuration.nix "${argononed}/OS/nixos" ];

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

  systemd.services.reboot = {
    enable = false;
    script = ''
      ${pkgs.systemd}/bin/shutdown -r now
    '';
  };

  systemd.timers.reboot = {
    enable = false;
    wantedBy = [ "timers.target" ];
    timerConfig.OnCalendar = [ "*-*-* 06:00:00" ];
  };

  services.argonone = {
    enable = false;
    logLevel = 4;
    settings = {
      fanTemp0 = 36;
      fanSpeed0 = 10;
      fanTemp1 = 41;
      fanSpeed1 = 50;
      fanTemp2 = 46;
      fanSpeed2 = 80;
      hysteresis = 4;
    };
  };

  #############################################################################
  ## Package management
  #############################################################################

  environment.systemPackages = with pkgs; [
    atop
    ffmpeg
    libraspberrypi
    iotop
    smartmontools
    kid3
    python3
    restic
    sysstat
    yt-dlp
    mailutils
  ];

  #############################################################################
  ## Modules
  #############################################################################

  age.secrets."restic-small-files-password".file =
    myUtils.secrets.file "restic-small-files-password";
  age.secrets."rclone.conf".file = myUtils.secrets.file "rclone.conf";

  modules.actualbudget.enable = false;
  modules.aria2.enable = true;
  modules.backup.small-files = {
    enable = true;
    rcloneConfigFile = config.age.secrets."rclone.conf".path;
    passwordFile = config.age.secrets."restic-small-files-password".path;
    healthcheck =
      "https://healthchecks.${catalog.domain.service}/ping/2d062a25-b297-45c0-a2b3-cdb188802fb8";
    # Prune should only be executed on one host
    prune = true;
  };

  modules.backup.usb = {
    enable = true;
    rcloneConfigFile = config.age.secrets."rclone.conf".path;
  };
  modules.caddy.enable = true;
  modules.dns.enable = true;
  modules.healthchecks.enable = true;
  modules.minio.enable = true;
  modules.monitoring.enable = true;
  modules.mopidy.enable = false;
  modules.navidrome.enable = false;
  modules.nfs-server.enable = true;
  modules.plex.enable = true;
  modules.unifi.enable = true;

  services.prometheus.exporters.zfs.enable = true;
}

