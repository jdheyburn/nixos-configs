{ config, pkgs, lib, ... }:

with lib;

let grafanaPort = 2342;
in {

  networking.firewall.allowedTCPPorts = [ grafanaPort ];

  services.grafana = {
    enable = true;
    domain = "grafana.svc.joannet.casa";
    port = grafanaPort;
    addr = "127.0.0.1";
  };
}
