{ catalog, config, pkgs, lib, ... }:
with lib;
{
  options.modules.prometheusStack.enable = mkEnableOption "Deploy Prometheus suite";

  imports = [
    ./blackbox-exporter.nix
    ./grafana.nix
    ./loki.nix
    ./victoria-metrics.nix
  ];
}
