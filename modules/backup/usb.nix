{ config, pkgs, lib, ... }:

with lib;

let

  cfg = config.modules.backup.usb;

  healthcheckResticMedia = "https://healthchecks.svc.joannet.casa/ping/ddc2053b-0b28-48ad-9044-ecdcc79446d9";

  healthcheckRcloneMedia =
    "https://healthchecks.svc.joannet.casa/ping/8f0ec51d-39b8-4853-8f7a-6076eb3ec60d";

in
{

  options.modules.backup.usb = {
    enable = mkEnableOption "Enable backup of media and rclone to cloud";
  };

  config = mkIf cfg.enable
    {
      age.secrets."restic-media-password".file =
        ../../secrets/restic-media-password.age;

      services.restic.backups.media = {
        repository = "/mnt/nfs/restic/media";
        passwordFile = config.age.secrets."restic-media-password".path;
        pruneOpts = [
          "--keep-daily 30"
          "--keep-weekly 5"
          "--keep-monthly 12"
          "--keep-yearly 3"
        ];
        paths = [
          "/mnt/usb/Backup/media/beets-db"
          "/mnt/usb/Backup/media/lossless"
          "/mnt/usb/Backup/media/music"
          "/mnt/usb/Backup/media/vinyl"
        ];
        timerConfig = { OnCalendar = "*-*-* 02:00:00"; };
        backupPrepareCommand = "${pkgs.curl}/bin/curl ${healthcheckResticMedia}/start";
        backupCleanupCommand = "${pkgs.curl}/bin/curl ${healthcheckResticMedia}";
      };

      # Once media has been backed up, rsync to cloud storage
      systemd.services.rclone-media = {
        enable = true;
        wantedBy = [ "restic-backups-media.service" ];
        after = [ "restic-backups-media.service" ];
        environment = {
          RCLONE_CONF_PATH = config.age.secrets."rclone.conf".path;
        };
        script = ''
          ${pkgs.curl}/bin/curl ${healthcheckRcloneMedia}/start

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

          ${pkgs.curl}/bin/curl ${healthcheckRcloneMedia}
        '';
      };
    };
}
