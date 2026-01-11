{ config, pkgs, lib, ... }:

with lib;

let cfg = config.modules.nfs-client;
in {

  options.modules.nfs-client = { enable = mkEnableOption "Mount NFS drive"; };

  config = mkIf cfg.enable {

    fileSystems."/mnt/nfs" = {
      device = "dee:/mnt/nfs";
      fsType = "nfs";
      options = [
        "x-systemd.automount"
        "x-systemd.requires=tailscaled.service"
        "x-systemd.before=tailscaled.service"
      ];
    };

    #systemd.services.nfs-mountd.requires = [ "tailscale-online.target" ];
    #    systemd.services.nfs-mountd.requires = [ "tailscaled.service" ];

    #systemd.services."mnt-fs".requisite = [ "tailscale-online.target" ];
    #  systemd.services."mnt-fs.mount".after = [ "tailscale-online.target" ];
    #  systemd.services."mnt-fs.mount".requiredBy = [ "tailscale-online.target" ];

  };
}
