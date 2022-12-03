{ catalog, config, pkgs, lib }: {
  enable = config.modules.prometheusStack.prometheus.enable;
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
          http.fail_if_not_ssl = true;
          http.preferred_ip_protocol = "ip4";
          # 401 and 403 because this is what minio and plex return
          # TODO investigate a blackbox on each node for TLS services
          # where their TLS port is not open
          http.valid_status_codes = [ 200 401 403 ];
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
