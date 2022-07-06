{ config, pkgs, lib, ... }:

with lib;

let
  cfg = config.modules.monitoring;

  nodeExporterPort = 9002;
in {

  imports = [ ./promtail.nix ];

  options.modules.monitoring = {
    enable = mkEnableOption "Enable Prometheus monitoring of this box";
    enablePromtail = mkEnableOption "Enable promtail module";
  };

  config = mkIf cfg.enable {

    networking.firewall.allowedTCPPorts = [ nodeExporterPort ];

    services.prometheus.exporters.node = {
      enable = true;
      enabledCollectors = [ "systemd" ];
      port = nodeExporterPort;
    };

    modules.promtail.enable = cfg.enablePromtail;

  };
}
