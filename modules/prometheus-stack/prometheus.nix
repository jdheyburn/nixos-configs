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
      # TODO define this via nix
      configFile = ./blackbox.yaml;
    };
  };
  scrapeConfigs = import ./scrape-configs.nix { inherit catalog config lib; };
}
