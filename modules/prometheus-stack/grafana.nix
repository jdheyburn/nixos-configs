{ catalog, config, pkgs }:

{
  enable = true;
  domain = "grafana.svc.joannet.casa";
  port = catalog.services.grafana.port;
  addr = "0.0.0.0";
  analytics.reporting.enable = false;

  declarativePlugins = with pkgs.grafanaPlugins; [ grafana-piechart-panel ];

  provision = {
    enable = true;
    datasources = [
      {
        name = "Prometheus";
        type = "prometheus";
        url = "http://localhost:${toString config.services.prometheus.port}";
        isDefault = true;
        jsonData = {
          timeInterval = "5s"; # node is scraping at 5s
        };
      }
      {
        name = "Loki";
        type = "loki";
        url = "http://localhost:${
            toString config.services.loki.configuration.server.http_listen_port
          }";
      }
    ];
  };
}

