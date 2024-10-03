{ config, pkgs, lib, ... }:

with lib;

let cfg = config.modules.plex;
in {

  options.modules.plex = { enable = mkEnableOption "Deploy plex"; };

  config = mkIf cfg.enable {

    services.caddy.virtualHosts."plex.svc.joannet.casa".extraConfig = ''
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

