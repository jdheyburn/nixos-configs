{ config, pkgs, lib, ... }:

with lib;

let cfg = config.modules.nfs-server;
in {

  options.modules.nfs-server = { enable = mkEnableOption "Deploy NFS server"; };

  config = mkIf cfg.enable {

    networking.firewall = {

      allowedTCPPorts = [
        2049 # NFS
        111 # NFS
        8200 # minidlna
      ];

      allowedUDPPorts = [
        111 # NFS
        2049 # NFS
        8200 # minidlna
      ];
    };

    services.nfs.server.enable = true;
    services.nfs.server.exports = ''
      /mnt/nfs *(rw,insecure,all_squash,anonuid=1000,anongid=100)
    '';

    #services.nfs.server.exports = ''
    #   /mnt/nfs 192.168.1.20(rw,nohide,insecure) 192.168.1.25(rw,nohide,insecure,all_squash,anonuid=1000,anongid=100) 192.168.1.26(rw,nohide,insecure,anonuid=1000,anongid=100) 192.168.1.12(rw,nohide,insecure)
    #'';

    # Did some experimenting with this in the past, might come back to it
    services.samba = {
      enable = false;
      openFirewall = true;
      shares = {
        usb = {
          path = "/mnt/nfs";
          writeable = "yes";
          "force user" = "root";
          "force group" = "root";
          "guest ok" = "yes";
        };
      };
      settings = {
        "hosts allow" = "192.168.1.20 192.168.1.25 192.168.1.25 localhost";
        "hosts deny" = "0.0.0.0/0";
      };
    };

    services.minidlna = {
      enable = true;
      settings = {
        notify_interval = 60;
        friendly_name = "dee";
        media_dir = [ "V,/mnt/nfs/media/tv/" "A,/mnt/nfs/media/music/" ];
      };
    };
  };
}
