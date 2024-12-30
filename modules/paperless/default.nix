{ catalog, config, pkgs, lib, ... }:

with lib;

let
  cfg = config.modules.paperless;
  port = catalog.services.paperless.port;
in {

  options.modules.paperless = {
    enable = mkEnableOption "Deploy paperless-ngx";
  };

  config = mkIf cfg.enable {

    services.caddy.virtualHosts."paperless.${catalog.domain.service}".extraConfig = ''
      tls {
        dns cloudflare {env.CLOUDFLARE_API_TOKEN}
      }
      reverse_proxy localhost:${toString port}
    '';

    #networking.firewall.allowedTCPPorts =
    #  [ catalog.services.paperless.port ];

    services.paperless = {
      enable = true;
      address = "0.0.0.0";
      port = port;
    };
  };
}
