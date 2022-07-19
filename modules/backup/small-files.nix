{ config, pkgs, lib, ... }:

with lib;

let

  cfg = config.modules.backupSF;

in {

  options.modules.backupSF = {
    enable =
      mkEnableOption "Enable backup of defined paths to small-files repo";

    repository = mkOption {
      type = types.str;
      default = "/mnt/nfs/restic/small-files";
    };

    passwordFile = mkOption { type = types.path; };

    # TODO discover what paths to backup depending on what services are running on the box
    # then change this to allow extraPaths
    paths = mkOption { type = types.listOf types.str; };

    backupTime = mkOption {
      type = types.str;
      default = "*-*-* 02:00:00";
    };

    prune = mkOption {
      type = types.bool;
      default = false;
    };

    pruneTime = mkOption {
      type = types.str;
      default = "*-*-* 02:30:00";
    };

  };

  config = mkIf cfg.enable (mkMerge [
    {
      services.restic.backups.small-files = {
        repository = cfg.repository;
        passwordFile = cfg.passwordFile;
        paths = cfg.paths;
        timerConfig = { OnCalendar = cfg.backupTime; };
      };
    }

    (mkIf cfg.prune {
      services.restic.backups.small-files-prune = {
        repository = cfg.repository;
        passwordFile = cfg.passwordFile;
        pruneOpts = [
          "--keep-daily 7"
          "--keep-weekly 5"
          "--keep-monthly 12"
          "--keep-yearly 3"
        ];
        timerConfig = { OnCalendar = cfg.pruneTime; };
      };
    })
  ]);
}
