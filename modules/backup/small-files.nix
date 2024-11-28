{ config, pkgs, lib, ... }:

with lib;

let

  cfg = config.modules.backup.small-files;

  healthcheckAfter =
    if cfg.prune then
      "restic-backups-small-files-prune.service"
    else
      "restic-backups-small-files.service";

in
{

  options.modules.backup.small-files = {
    enable =
      mkEnableOption "Enable backup of defined paths to small-files repo";

    repository = mkOption {
      type = types.str;
      default = "rclone:b2:iifu8Noi-backups/restic/small-files";
    };

    passwordFile = mkOption { type = types.path; };

    extraBackupArgs = mkOption {
      type = types.listOf types.str;
      default = [ ];
    };

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

    healthcheck = mkOption {
      type = types.str;
      default = "";
    };

  };

  config = mkIf cfg.enable (mkMerge [
    {
      services.restic.backups.small-files = {
        repository = cfg.repository;
        passwordFile = cfg.passwordFile;
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

    (mkIf (cfg.healthcheck != "") {
      systemd.services.restic-backups-small-files-healthcheck = {
        enable = true;
        wantedBy = [ healthcheckAfter ];
        after = [ healthcheckAfter ];
        environment = { HEALTHCHECK_ENDPOINT = cfg.healthcheck; };
        script = ''
          echo "sending healthcheck to $HEALTHCHECK_ENDPOINT"
          ${pkgs.curl}/bin/curl -v $HEALTHCHECK_ENDPOINT
        '';
      };
    })
  ]);
}
