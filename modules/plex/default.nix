{ config, pkgs, lib, ... }:

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

    services.caddy.virtualHosts."plex.${catalog.domain.service}".extraConfig = ''
      tls {
        dns cloudflare {env.CLOUDFLARE_API_TOKEN}
      }
      reverse_proxy localhost:32400
    '';

    services.plex = {
      enable = true;
      openFirewall = true;
    };

    systemd.services.plex.serviceConfig.TimeoutStartSec = "5m";
  };
}

