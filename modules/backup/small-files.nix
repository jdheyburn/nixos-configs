{ config, pkgs, lib, ... }:

with lib;

let

  cfg = config.modules.backupSF;

in {

  options.modules.backupSF = {
    enable =
      mkEnableOption "Enable backup of defined paths to small-files repo";

    repository = mkOption { type = types.str; };

    passwordFile = mkOption { type = types.path; };

    paths = mkOption { type = types.listOf types.str; };

    backupTime = mkOption {
      type = types.str;
      default = "*-*-* 02:00:00";
    };

  };

  config = mkIf cfg.enable {

    services.restic.backups = {

      small-files = {
        repository = cfg.repository;
        passwordFile = cfg.passwordFile;
        pruneOpts = [
          "--keep-daily 7"
          "--keep-weekly 5"
          "--keep-monthly 12"
          "--keep-yearly 3"
        ];
        paths = cfg.paths;
        timerConfig = { OnCalendar = cfg.backupTime; };
      };
    };

  };
}

