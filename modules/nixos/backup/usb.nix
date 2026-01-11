{ catalog, config, pkgs, lib, utils, ... }:

with lib;

let

  cfg = config.modules.backup.usb;

  healthcheckResticMedia = "https://healthchecks.${catalog.domain.service}/ping/ddc2053b-0b28-48ad-9044-ecdcc79446d9";

  healthcheckRcloneMedia =
    "https://healthchecks.${catalog.domain.service}/ping/8f0ec51d-39b8-4853-8f7a-6076eb3ec60d";

in
{

  options.modules.backup.usb = {
    enable = mkEnableOption "Enable backup of media and rclone to cloud";

    rcloneConfigFile = mkOption { type = types.path; };
  };

  config = mkIf cfg.enable
    {
      age.secrets."restic-media-password".file =
        utils.secrets.file "restic-media-password";

      services.restic.backups.media = {
        repository = "rclone:b2:iifu8Noi-backups/restic/media";
        rcloneConfigFile = cfg.rcloneConfigFile;
        passwordFile = config.age.secrets."restic-media-password".path;
        pruneOpts = [
          "--keep-daily 30"
        ];
        paths = [
          "/mnt/usb/Backup/media/beets-db"
          "/mnt/usb/Backup/media/music"
        ];
        timerConfig = { OnCalendar = "*-*-* 02:00:00"; };
        backupPrepareCommand = "${pkgs.curl}/bin/curl ${healthcheckResticMedia}/start";
        backupCleanupCommand = ''
          preStartExitStatus=$(systemctl show restic-backups-media --property=ExecStartPre | grep -oEi 'status=([[:digit:]]+)' | cut -d '=' -f2)
          echo "preStartExitStatus=$preStartExitStatus"
          echo "EXIT_STATUS=$EXIT_STATUS"
          [ $preStartExitStatus -ne 0 ] && returnStatus=$preStartExitStatus || returnStatus=$EXIT_STATUS
          ${pkgs.curl}/bin/curl ${healthcheckResticMedia}/$returnStatus
        '';
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

          echo "rcloning minio -> b2:minio"
          ${pkgs.rclone}/bin/rclone -v sync minio: b2:iifu8Noi-backups/minio --config=$RCLONE_CONF_PATH

          ${pkgs.curl}/bin/curl ${healthcheckRcloneMedia}
        '';
      };
    };
}
