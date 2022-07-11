{ config, pkgs, lib, ... }:

with lib;

let

  cfg = config.modules.backupUSB;

in {

  options.modules.backupUSB = {
    enable = mkEnableOption "Enable backup of media and rclone to cloud";
  };

  config = mkIf cfg.enable {

    age.secrets."rclone.conf".file = ../../secrets/rclone.conf.age;

    age.secrets."restic-media-password".file =
      ../../secrets/restic-media-password.age;

    #    services.restic.backups = {
    #      media = {
    #        repository = "/mnt/nfs/restic/media";
    #        passwordFile = config.age.secrets."restic-media-password".path;
    #        pruneOpts = [
    #          "--keep-daily 30"
    #          "--keep-weekly 0"
    #          "--keep-monthly 0"
    #          "--keep-yearly 0"
    #        ];
    #        paths = [
    #          "/mnt/usb/Backup/media/beets-db"
    #          "/mnt/usb/Backup/media/lossless"
    #          "/mnt/usb/Backup/media/music"
    #          "/mnt/usb/Backup/media/vinyl"
    #        ];
    #        timerConfig = { OnCalendar = "*-*-* 02:00:00"; };
    #      };
    #    };

    systemd.services.rclone-media = {
      enable = false;
      # TODO can I refer to this from output of services.restic.backups.media ?
      wantedBy = [ "restic-backups-media.service" ];
      after = [ "restic-backups-media.service" ];
      environment = {
        RCLONE_CONF_PATH = config.age.secrets."rclone.conf".path;
      };
      script = ''
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
        echo "rclone restic/small-files -> b2:restic/small-files"
        ${pkgs.rclone}/bin/rclone -v sync /mnt/nfs/restic/small-files b2:iifu8Noi-backups/restic/small-files --config=$RCLONE_CONF_PATH
      '';
    };
  };
}
