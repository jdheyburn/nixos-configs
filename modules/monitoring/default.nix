{ catalog, config, pkgs, lib, ... }:

with lib;

let
  cfg = config.modules.monitoring;
in {

  imports = [ ./promtail.nix ];

  options.modules.monitoring = {
    enable = mkEnableOption "Enable Prometheus monitoring of this box";
    enablePromtail = mkOption {
      default = true;
      type = types.bool;
    };
  };

  config = mkIf cfg.enable {

    networking.firewall.allowedTCPPorts = [ config.services.prometheus.exporters.node.port ];

    services.prometheus.exporters.node = {
      enable = true;
      enabledCollectors = [ "systemd" ];
      port = catalog.services.nodeExporter.port;
    };

    modules.promtail.enable = cfg.enablePromtail;
  };
}

