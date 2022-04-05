{ config, pkgs, lib, ... }:

{

  services.restic.backups = {
    media = {
      repository = "/mnt/nfs/Backup/restic/media";
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
      repository = "/mnt/nfs/Backup/restic/small-files";
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
    enable = true;
    # TODO can I refer to this from output of services.restic.backups.media ?
    wantedBy = [ "restic-backups-media.service" ];
    after = [ "restic-backups-media.service" ];
    script = ''
     echo "rcloning beets-db -> gdrive:media/beets-db"
      ${pkgs.rclone}/bin/rclone -v sync /mnt/nfs/Backup/media/beets-db gdrive:media/beets-db --config=/etc/nixos/secrets/rclone.conf
  
      echo "rcloning music -> gdrive:media/music"
      ${pkgs.rclone}/bin/rclone -v sync /mnt/nfs/Backup/media/music gdrive:media/music --config=/etc/nixos/secrets/rclone.conf
      
      echo "rcloning lossless -> gdrive:media/lossless"
      ${pkgs.rclone}/bin/rclone -v sync /mnt/nfs/Backup/media/lossless gdrive:media/lossless --config=/etc/nixos/secrets/rclone.conf
      
      echo "rcloning vinyl -> gdrive:media/vinyl"
      ${pkgs.rclone}/bin/rclone -v sync /mnt/nfs/Backup/media/vinyl gdrive:media/vinyl --config=/etc/nixos/secrets/rclone.conf
      
      echo "rcloning restic/media -> b2:restic/media"
      ${pkgs.rclone}/bin/rclone -v sync /mnt/nfs/Backup/restic/media b2:iifu8Noi-backups/restic/media --config=/etc/nixos/secrets/rclone.conf
    '';
  };

  systemd.services.rclone-small-files = {
    enable = true;
    wantedBy = [ "restic-backups-small-files.service" ];
    after = [ "restic-backups-small-files.service" ];
    script = ''
      echo "rclone restic/small-files -> b2:restic/small-files"
      ${pkgs.rclone}/bin/rclone -v sync /mnt/nfs/Backup/restic/small-files b2:iifu8Noi-backups/restic/small-files --config=/etc/nixos/secrets/rclone.conf
    '';
  };
}
