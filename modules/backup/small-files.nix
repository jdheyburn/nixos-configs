{ catalog, config, pkgs, lib, ... }:

with lib;

let

  cfg = config.modules.backup.small-files;

  # Prune would only be executed on one host, so it has a static healthcheck
  healthcheckPrune = "https://healthchecks.${catalog.domain.service}/ping/fea7ebdd-b6dc-4eb5-b577-39aff3966ad4";
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

    rcloneConfigFile = mkOption { type = types.path; };

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
      default = "Tue *-*-* 02:30:00";
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
        rcloneConfigFile = cfg.rcloneConfigFile;
        passwordFile = cfg.passwordFile;
        timerConfig = { OnCalendar = cfg.backupTime; };
        backupPrepareCommand = "${pkgs.curl}/bin/curl ${cfg.healthcheck}/start";
        backupCleanupCommand = ''
          preStartExitStatus=$(systemctl show restic-backups-small-files --property=ExecStartPre | grep -oEi 'status=([[:digit:]]+)' | cut -d '=' -f2)
          echo "preStartExitStatus=$preStartExitStatus"
          echo "EXIT_STATUS=$EXIT_STATUS"
          [ $preStartExitStatus -ne 0 ] && returnStatus=$preStartExitStatus || returnStatus=$EXIT_STATUS
          ${pkgs.curl}/bin/curl ${cfg.healthcheck}/$returnStatus
        '';
      };
    }

    (mkIf cfg.prune {
      services.restic.backups.small-files-prune = {
        repository = cfg.repository;
        rcloneConfigFile = cfg.rcloneConfigFile;
        passwordFile = cfg.passwordFile;
        pruneOpts = [
          "--keep-daily 7"
          "--keep-weekly 5"
          "--keep-monthly 12"
          "--keep-yearly 3"
        ];
        timerConfig = { OnCalendar = cfg.pruneTime; };
        backupPrepareCommand = "${pkgs.curl}/bin/curl ${healthcheckPrune}/start";
        backupCleanupCommand = ''
          preStartExitStatus=$(systemctl show restic-backups-small-files-prune --property=ExecStartPre | grep -oEi 'status=([[:digit:]]+)' | cut -d '=' -f2)
          echo "preStartExitStatus=$preStartExitStatus"
          echo "EXIT_STATUS=$EXIT_STATUS"
          [ $preStartExitStatus -ne 0 ] && returnStatus=$preStartExitStatus || returnStatus=$EXIT_STATUS
          ${pkgs.curl}/bin/curl ${healthcheckPrune}/$returnStatus
        '';
      };
    })
  ]);
}
