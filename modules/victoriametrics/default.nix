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
  };
}
