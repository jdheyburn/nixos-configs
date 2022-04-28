{ config, pkgs, lib, ... }:

with lib;

let
  cfg = config.modules.unifi;

  unifiMinJavaHeapSize = 256;
in {

  options.modules.unifi = {
    enable = mkOption {
      type = types.bool;
      default = false;
    };
  };

  config = mkIf cfg.enable {

    networking.firewall.allowedTCPPorts =
      [ config.services.prometheus.exporters.unifi-poller.port ];

    age.secrets."unifi-poller-password".file =
      ../secrets/unifi-poller-password.age;
    age.secrets."unifi-poller-password".owner =
      config.services.prometheus.exporters.unifi-poller.user;

    services.unifi = {
      enable = true;
      unifiPackage = pkgs.unifiStable;
      maximumJavaHeapSize = unifiMinJavaHeapSize;
      jrePackage = pkgs.jre8_headless;
      # TODO explore if this can be closed, if Caddy reverse proxies enough
      # Port 8443 does not need to be open because caddy proxies 443 -> 8443
      # But other ports may need to be open for unifi operations
      openFirewall = true;
    };

    services.prometheus.exporters.unifi-poller = {
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
