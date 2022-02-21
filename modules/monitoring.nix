{ config, pkgs, lib, ... }:

let nodeExporterPort = 9002;
in {

  imports = [ ./promtail.nix ];

  networking.firewall.allowedTCPPorts = [ nodeExporterPort ];

  services.prometheus.exporters.node = {
    enable = true;
    enabledCollectors = [ "systemd" ];
    port = nodeExporterPort;
  };
}
