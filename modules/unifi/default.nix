{ config, catalog, pkgs, lib, ... }:

with lib;

let cfg = config.modules.unifi;
in {

  options.modules.unifi = {
    enable = mkEnableOption "Deploy unifi controller";
  };

  config = mkIf cfg.enable {

    services.caddy.virtualHosts."unifi.svc.joannet.casa".extraConfig = ''
      tls {
        dns cloudflare {env.CLOUDFLARE_API_TOKEN}
      }
      reverse_proxy localhost:${toString catalog.services.unifi.port} {
        transport http {
          tls_insecure_skip_verify
        }
      }
    '';

    # If doing a fresh install then you may need to open 8443
    # temporarily before you can close it out again
    networking.firewall.allowedTCPPorts =
      [ config.services.prometheus.exporters.unpoller.port 8443 ];

    age.secrets."unifi-poller-password".file =
      ../../secrets/unifi-poller-password.age;
    age.secrets."unifi-poller-password".owner =
      config.services.prometheus.exporters.unpoller.user;

    services.unifi = {
      enable = true;
      unifiPackage = pkgs.unifi7;
      maximumJavaHeapSize = 256;
      openFirewall = true;
    };

    services.prometheus.exporters.unpoller = {
      enable = true;
      controllers = [{
        url = "https://unifi.svc.joannet.casa";
        user = "unifipoller";
        pass = config.age.secrets."unifi-poller-password".path;
        save_ids = true;
        save_events = true;
        save_alarms = true;
        save_anomalies = true;
      }];

      # loki = {
      #   url = "https://loki.svc.joannet.casa";
      #   verify_ssl = true;
      # };
    };

  };
}
