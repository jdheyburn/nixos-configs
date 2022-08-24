{ catalog, config, pkgs, lib }: {
  enable = true;
  port = catalog.services.prometheus.port;
  webExternalUrl = "https://prometheus.svc.joannet.casa";

  # Thanos stores long term metrics
  retentionTime = "1d";

  extraFlags = [
    "--storage.tsdb.min-block-duration=2h"
    "--storage.tsdb.max-block-duration=2h"
  ];

  globalConfig = {
    external_labels = { prometheus = "${config.networking.hostName}"; };
  };

  exporters = {
    node = {
      enable = true;
      port = catalog.services.nodeExporter.port;
    };
    blackbox = {
      enable = true;
      configFile = pkgs.writeText "blackbox.json" (builtins.toJSON {
        modules.http_2xx = {
          prober = "http";
          timeout = "5s";
          http.preferred_ip_protocol = "ip4";
        };
        modules.tls_connect = {
          prober = "tcp";
          timeout = "5s";
          tcp.tls = true;
        };
      });
    };
  };
  scrapeConfigs = import ./scrape-configs.nix { inherit catalog config lib; };
}
