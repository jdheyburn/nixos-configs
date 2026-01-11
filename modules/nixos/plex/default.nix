{ catalog, config, pkgs, lib, utils, ... }:

with lib;

let cfg = config.modules.plex;
in {

  options.modules.plex = {
    enable = mkEnableOption "Deploy plex";
  };

  config = mkIf cfg.enable {

    services.restic.backups.small-files = {
      paths = [
        config.services.plex.dataDir
      ];
      exclude = [ "/var/lib/plex/Plex Media Server/Cache" ];
    };

    services.caddy.virtualHosts."plex.${catalog.domain.service}".extraConfig =
      utils.caddy.mkServiceVHost {
        port = 32400;
        resolvers = false;
      };

    services.plex = {
      enable = true;
      openFirewall = true;
    };

    systemd.services.plex.serviceConfig.TimeoutStartSec = "5m";
  };
}

