{ config, pkgs, lib, ... }:

{

  services.restic.backups = {
    media = {
      repository = "/mnt/usb/Backup/restic/media";
      passwordFile = "/etc/nixos/secrets/restic-media-password";
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

    small-files = {
      repository = "/mnt/usb/Backup/restic/small-files";
      passwordFile = "/etc/nixos/secrets/restic-small-files-password";
      pruneOpts = [
        "--keep-daily 7"
        "--keep-weekly 5"
        "--keep-monthly 12"
        "--keep-yearly 3"
      ];
      paths = [
        "/var/lib/unifi/data/backup/autobackup"
        "/var/lib/AdGuardHome/"
        "/var/lib/private/AdGuardHome"
      ];
      timerConfig = { OnCalendar = "*-*-* 02:00:00"; };
    };
  };

  systemd.services.rclone-media = {
    # TODO can I refer to this from output of services.restic.backups.media ?
    wantedBy = [ "restic-backups-media.service" ];
    after = [ "restic-backups-media.service" ];
    environment = {
      RCLONE_CONFIG = "/etc/nixos/secrets/rclone.conf";
      RCLONE = "${pkgs.rclone}/bin/rclone";
      BACKUP_TYPE = "media";
    };
    serviceConfig = {
      Type = "oneshot";
      ExecStart =
        "${pkgs.bash}/bin/bash /home/jdheyburn/dotfiles/restic/rclone-all.sh";
    };
  };

  systemd.services.rclone-small-files = {
    wantedBy = [ "restic-backups-small-files.service" ];
    after = [ "restic-backups-small-files.service" ];
    environment = {
      RCLONE_CONFIG = "/etc/nixos/secrets/rclone.conf";
      RCLONE = "${pkgs.rclone}/bin/rclone";
      BACKUP_TYPE = "small-files";
    };
    serviceConfig = {
      Type = "oneshot";
      ExecStart =
        "${pkgs.bash}/bin/bash /home/jdheyburn/dotfiles/restic/rclone-all.sh";
    };
  };
}
