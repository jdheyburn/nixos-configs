{ config, pkgs, lib, ... }:

with lib;

let

  cfg = config.modules.backupUSB;

  # TODO refactor into function
  healthcheckRcloneMediaStartScript =
    optionalString (cfg.healthcheckRcloneMedia != "") ''
      echo "sending start healthcheck to ${cfg.healthcheckRcloneMedia}/start"
      ${pkgs.curl}/bin/curl -v ${cfg.healthcheckRcloneMedia}/start
    '';

  healthcheckRcloneMediaFinishScript =
    optionalString (cfg.healthcheckRcloneMedia != "") ''
      echo "sending finish healthcheck to ${cfg.healthcheckRcloneMedia}"
      ${pkgs.curl}/bin/curl -v ${cfg.healthcheckRcloneMedia}
    '';

  healthcheckRcloneSmallFilesStartScript =
    optionalString (cfg.healthcheckRcloneSmallFiles != "") ''
      echo "sending start healthcheck to ${cfg.healthcheckRcloneSmallFiles}/start"
      ${pkgs.curl}/bin/curl -v ${cfg.healthcheckRcloneSmallFiles}/start
    '';

  healthcheckRcloneSmallFilesFinishScript =
    optionalString (cfg.healthcheckRcloneSmallFiles != "") ''
      echo "sending finish healthcheck to ${cfg.healthcheckRcloneSmallFiles}"
      ${pkgs.curl}/bin/curl -v ${cfg.healthcheckRcloneSmallFiles}
    '';

in {

  options.modules.backupUSB = {
    enable = mkEnableOption "Enable backup of media and rclone to cloud";
    healthcheckResticMedia = mkOption {
      type = types.str;
      default = "";
    };
    healthcheckRcloneMedia = mkOption {
      type = types.str;
      default = "";
    };
    healthcheckRcloneSmallFiles = mkOption {
      type = types.str;
      default = "";
    };
  };

  config = mkIf cfg.enable (mkMerge [
    {

      age.secrets."rclone.conf".file = ../../secrets/rclone.conf.age;

      age.secrets."restic-media-password".file =
        ../../secrets/restic-media-password.age;

      services.restic.backups.media = {
        repository = "/mnt/nfs/restic/media";
        passwordFile = config.age.secrets."restic-media-password".path;
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
        timerConfig = { OnCalendar = "*-*-* 02:00:00"; };
      };

      systemd.services.rclone-media = {
        enable = true;
        # TODO can I refer to this from output of services.restic.backups.media ?
        wantedBy = [ "restic-backups-media.service" ];
        after = [ "restic-backups-media.service" ];
        environment = {
          RCLONE_CONF_PATH = config.age.secrets."rclone.conf".path;
        };
        script = ''
          ${healthcheckRcloneMediaStartScript}

          echo "rcloning beets-db -> gdrive:media/beets-db"
          ${pkgs.rclone}/bin/rclone -v sync /mnt/nfs/media/beets-db gdrive:media/beets-db --config=$RCLONE_CONF_PATH

          echo "rcloning music -> gdrive:media/music"
          ${pkgs.rclone}/bin/rclone -v sync /mnt/nfs/media/music gdrive:media/music --config=$RCLONE_CONF_PATH

          echo "rcloning lossless -> gdrive:media/lossless"
          ${pkgs.rclone}/bin/rclone -v sync /mnt/nfs/media/lossless gdrive:media/lossless --config=$RCLONE_CONF_PATH

          echo "rcloning vinyl -> gdrive:media/vinyl"
          ${pkgs.rclone}/bin/rclone -v sync /mnt/nfs/media/vinyl gdrive:media/vinyl --config=$RCLONE_CONF_PATH

          echo "rcloning restic/media -> b2:restic/media"
          ${pkgs.rclone}/bin/rclone -v sync /mnt/nfs/restic/media b2:iifu8Noi-backups/restic/media --config=$RCLONE_CONF_PATH

          echo "rcloning minio -> b2:minio"
          ${pkgs.rclone}/bin/rclone -v sync minio: b2:iifu8Noi-backups/minio --config=$RCLONE_CONF_PATH

          ${healthcheckRcloneMediaFinishScript}
        '';
      };

      systemd.services.rclone-small-files = {
        enable = true;
        wantedBy = [ "restic-backups-small-files-prune.service" ];
        after = [ "restic-backups-small-files-prune.service" ];
        environment = {
          RCLONE_CONF_PATH = config.age.secrets."rclone.conf".path;
        };
        script = ''
          ${healthcheckRcloneSmallFilesStartScript}

          echo "rclone restic/small-files -> b2:restic/small-files"
          ${pkgs.rclone}/bin/rclone -v sync /mnt/nfs/restic/small-files b2:iifu8Noi-backups/restic/small-files --config=$RCLONE_CONF_PATH

          ${healthcheckRcloneSmallFilesFinishScript}
        '';
      };
    }

    (mkIf (cfg.healthcheckResticMedia != "") {
      systemd.services.restic-backups-media-healthcheck = {
        enable = true;
        wantedBy = [ "restic-backups-media.service" ];
        after = [ "restic-backups-media.service" ];
        environment = { HEALTHCHECK_ENDPOINT = cfg.healthcheckResticMedia; };
        script = ''
          echo "sending healthcheck to $HEALTHCHECK_ENDPOINT"
          ${pkgs.curl}/bin/curl -v $HEALTHCHECK_ENDPOINT
        '';
      };
    })
  ]);
}
