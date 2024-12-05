{ catalog, config, pkgs, lib, ... }:

with lib;

let cfg = config.modules.prometheusStack;

in {
  options.modules.prometheusStack.victoriametrics.enable = mkEnableOption "Deploy VictoriaMetrics";

  config = mkIf (cfg.enable && cfg.victoriametrics.enable) {
    services.caddy.virtualHosts."victoriametrics.svc.joannet.casa".extraConfig = ''
      tls {
        dns cloudflare {env.CLOUDFLARE_API_TOKEN}
        # Below required to get TLS to work on non-local hosts (i.e. charlie)
        resolvers 8.8.8.8
      }
      reverse_proxy localhost:${toString catalog.services.victoriametrics.port}
    '';

    services.victoriametrics = {
      enable = true;
      prometheusConfig.scrape_configs = import ./scrape-configs.nix { inherit catalog config lib; };
    };

    systemd.services.victoriametrics.serviceConfig.TimeoutStartSec = "5m";

    services.restic.backups.small-files = {
      paths = [ "/var/lib/${config.services.victoriametrics.stateDir}" ];
    };
  };
}
