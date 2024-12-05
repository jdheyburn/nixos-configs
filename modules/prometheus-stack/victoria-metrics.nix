{ catalog, config, pkgs, lib, ... }:

with lib;

let
  json = pkgs.formats.json { };

  promConfig = {
    scrape_configs =
      import ./scrape-configs.nix { inherit catalog config lib; };
  };

  prometheusYml = json.generate "prometheus.yml" promConfig;

in
{
  enable = config.modules.prometheusStack.victoriametrics.enable;
  prometheusConfig = promConfig;
}
