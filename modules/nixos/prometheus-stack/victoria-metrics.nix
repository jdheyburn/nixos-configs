{ catalog, config, flake-self, pkgs, lib, myUtils, ... }:

with lib;

let cfg = config.modules.prometheusStack;

in {
  options.modules.prometheusStack.victoriametrics.enable = mkEnableOption "Deploy VictoriaMetrics";

  config = mkIf (cfg.enable && cfg.victoriametrics.enable) {
    age.secrets."victoriametrics-license" = {
      file = myUtils.secrets.file "victoriametrics-license";
      # victoriametrics systemd runs as DynamicUser
      mode = "0444";
    };

    services.caddy.virtualHosts."victoriametrics.${catalog.domain.service}".extraConfig =
      myUtils.caddy.mkServiceVHost {
        port = catalog.services.victoriametrics.port;
      };

    services.victoriametrics = {
      enable = true;
      #package = pkgs.victoriametrics-enterprise;
      prometheusConfig.scrape_configs = import ./scrape-configs.nix { inherit catalog config flake-self lib; };
      #extraOptions = [ "-licenseFile=${config.age.secrets."victoriametrics-license".path}" ];
      extraOptions = [ "-selfScrapeInterval=10s" ];
    };

    systemd.services.victoriametrics.serviceConfig.TimeoutStartSec = "5m";

    services.restic.backups.small-files = {
      paths = [ "/var/lib/${config.services.victoriametrics.stateDir}" ];
    };
  };
}
