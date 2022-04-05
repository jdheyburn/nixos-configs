{ config, pkgs, lib, ... }:

{
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
  # couldn't get 1.25 to work on macos, leaving here so i can see what did and didn't work
  services.nfs.server.exports = ''
    /mnt/nfs 192.168.1.20(rw,nohide,insecure) 192.168.1.25(rw,nohide,insecure,no_subtree_check,all_squash,anonuid=1001,anongid=1001) 192.168.1.26(rw,nohide,insecure)
  '';

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
    extraConfig = ''
      hosts allow = 192.168.1.20 192.168.1.25 192.168.1.25 localhost
      hosts deny = 0.0.0.0/0
    '';
  };

  services.minidlna = {
    enable = true;
    announceInterval = 60;
    friendlyName = "dee";
    mediaDirs =
      [ "V,/mnt/nfs/Backup/media/tv/" "A,/mnt/nfs/Backup/media/music/" ];
  };
}
