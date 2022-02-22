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

  services.unifi-poller = {
    # TODO needs config of user and password here?
    unifi.url = "https://localhost:8443";
    unifi.user = "unifipoller";
    unifi.pass = "/etc/nixos/secrets/unifi-poller-password";
    unifi.verify_ssl = false;
  };

  services.prometheus.exporters.unifi-poller = {
    enable = true;

  };
}
