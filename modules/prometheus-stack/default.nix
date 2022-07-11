{ catalog, config, pkgs, lib, ... }:

with lib;

let cfg = config.modules.prometheusStack;
in {
  options.modules.prometheusStack = {
    # TODO the string passed to these should be something simple as it gets appended to 'Whether to enable '
    enable = mkEnableOption "Deploy Prometheus suite";
  };

  config = mkIf cfg.enable {

    networking.firewall.allowedTCPPorts = [
      catalog.services.grafana.port
      catalog.services.loki.port
      catalog.services.prometheus.port
    ];

    services.grafana = import ./grafana.nix { inherit catalog config pkgs; };
    services.loki = import ./loki.nix { inherit catalog pkgs; };
    services.prometheus =
      import ./prometheus.nix { inherit catalog config pkgs; };
  };
}
