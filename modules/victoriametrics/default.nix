{ catalog, config, pkgs, lib, ... }:

with lib;

let
  json = pkgs.formats.json { };
  cfg = config.modules.victoriametrics;

  promConfig = {
    scrape_configs = import ../prometheus-stack/scrape-configs.nix {
      inherit catalog config lib;
    };
  };

  prometheusYml = json.generate "prometheus.yml" promConfig;

in {

  options.modules.victoriametrics = {
    enable = mkEnableOption "victoriametrics";
  };

  config = mkIf cfg.enable {

    services.victoriametrics = {
      enable = true;
      extraOptions = [ "-promscrape.config=${prometheusYml}" ];
    };

    # Default was 90s, and when doing a deploy via deploy-rs after a flake update where everything gets stopped and started
    # caused it to timeout due to CPU strain I guess. Extending it solved the problem.
    systemd.services.victoriametrics.serviceConfig.TimeoutStartSec = "5m";
  };
}
