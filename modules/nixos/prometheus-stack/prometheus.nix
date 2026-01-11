{ catalog, config, pkgs, lib }: {
  enable = config.modules.prometheusStack.prometheus.enable;
  port = catalog.services.prometheus.port;
  webExternalUrl = "https://prometheus.${catalog.domain.service}";

  # Thanos stores long term metrics
  retentionTime = "1d";

  extraFlags = [
    "--storage.tsdb.min-block-duration=2h"
    "--storage.tsdb.max-block-duration=2h"
  ];

  globalConfig = {
    external_labels = { prometheus = "${config.networking.hostName}"; };
  };

  scrapeConfigs = import ./scrape-configs.nix { inherit catalog config lib; };
}
