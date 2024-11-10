{ config, catalog, pkgs, lib, ... }:

with lib;

let cfg = config.modules.paperless;
in {

  options.modules.paperless = {
    enable = mkEnableOption "Deploy paperless-ngx";
  };

  config = mkIf cfg.enable {

    services.caddy.virtualHosts."paperless.svc.joannet.casa".extraConfig = ''
      tls {
        dns cloudflare {env.CLOUDFLARE_API_TOKEN}
      }
      reverse_proxy localhost:${toString catalog.services.paperless.port}
    '';

    #networking.firewall.allowedTCPPorts =
    #  [ catalog.services.paperless.port ];

    services.paperless = {
      enable = true;
      address = "0.0.0.0";
      port = catalog.services.paperless.port;
    };
  };
}
