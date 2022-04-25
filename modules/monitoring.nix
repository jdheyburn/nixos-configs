{ config, pkgs, lib, ... }:

with lib;

let
  cfg = config.modules.monitoring;

  nodeExporterPort = 9002;
in {

  imports = [ ./promtail.nix ];


  options.modules.monitoring = {
    enable = mkOption { type = types.bool; default = false; };
    enablePromtail = mkOption { type = types.bool; default = true; };
  };

  config = mkIf cfg.enable {

  # TODO enables promtail by default - should make this configurable?

  networking.firewall.allowedTCPPorts = [ nodeExporterPort ];

  services.prometheus.exporters.node = {
    enable = true;
    enabledCollectors = [ "systemd" ];
    port = nodeExporterPort;
  };

  modules.promtail.enable = cfg.enablePromtail;

  };
}
