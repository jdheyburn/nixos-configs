{ argononed, config, pkgs, lib, ... }:
let

  backupPaths = with lib;
    (optional config.services.unifi.enable
      "/var/lib/unifi/data/backup/autobackup")
    ++ (optionals config.services.adguardhome.enable [
      "/var/lib/AdGuardHome/"
      "/var/lib/private/AdGuardHome"
    ]) ++ (optionals config.services.plex.enable
      [ ''"/var/lib/plex/Plex Media Server"'' ]);

  backupExcludePaths = with lib;
    concatStrings [
      "--exclude="
      (concatStringsSep " " (optionals config.services.plex.enable
        [ ''"/var/lib/plex/Plex Media Server/Cache"'' ]))
    ];

in {

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
    enable = true;
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
    libraspberrypi
    iotop
    smartmontools
    kid3
    python39
    restic
    sysstat
    yt-dlp
  ];

  #############################################################################
  ## Modules
  #############################################################################

  age.secrets."restic-small-files-password".file =
    ../../secrets/restic-small-files-password.age;

  modules.backupSF = {
    enable = true;
    passwordFile = config.age.secrets."restic-small-files-password".path;
    paths = backupPaths;
    extraBackupArgs = [ backupExcludePaths ];
    prune = true;
    healthcheck =
      "https://healthchecks.svc.joannet.casa/ping/2d062a25-b297-45c0-a2b3-cdb188802fb8";
  };

  modules.backupUSB = {
    enable = true;
    healthcheckRcloneSmallFiles =
      "https://healthchecks.svc.joannet.casa/ping/09a44191-9fa2-4664-8f8b-2ef244f8576f";
    healthcheckRcloneMedia =
      "https://healthchecks.svc.joannet.casa/ping/8f0ec51d-39b8-4853-8f7a-6076eb3ec60d";
    healthcheckResticMedia =
      "https://healthchecks.svc.joannet.casa/ping/ddc2053b-0b28-48ad-9044-ecdcc79446d9";
  };
  modules.caddy.enable = true;
  modules.dns.enable = true;
  modules.healthchecks.enable = true;
  modules.minio.enable = true;
  modules.monitoring.enable = true;
  modules.mopidy.enable = false;
  modules.navidrome.enable = false;
  modules.nfs.enable = true;
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

