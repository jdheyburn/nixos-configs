{ config, pkgs, lib, ... }:

with lib;

let unifiMinJavaHeapSize = 256;
in {

  networking.firewall.allowedTCPPorts =
    [ config.services.prometheus.exporters.unifi-poller.port ];

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
      pass = "/etc/nixos/secrets/unifi-poller-password";
      save_ids = true;
      save_events = true;
      save_alarms = true;
      save_anomalies = true;
    }];

    # loki = {
    #   url = "https://loki.svc.joannet.casa"

    # };
  };
}
