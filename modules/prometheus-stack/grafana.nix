{ catalog, config, pkgs }:

{
  enable = true;

  settings = {
    analytics.reporting_enabled = false;

    server = {
      root_url = "https://grafana.svc.joannet.casa";
      http_addr = "0.0.0.0";
      http_port = catalog.services.grafana.port;
    };

    smtp = {
      enabled = true;
      host = "smtp.gmail.com:587";
      # from_address = "jdheyburn@gmail.com";
      user = "jdheyburn@gmail.com";
      password = "$__file{${config.age.secrets."smtp-password".path}}";
    };
  };

  declarativePlugins = with pkgs.grafanaPlugins; [ grafana-piechart-panel ];

  provision = {
    enable = true;
    # TODO Not sure if this actually works.. the datasource provision above works for existing deployments
    alerting.contactPoints.settings.contactPoints = [{
      name = "email-me";
      uid = "email-me";
      type = "email";
      is_default = true;
      disable_resolve_message = false;
      settings = { addresses = "jdheyburn@gmail.com"; };
    }];

    datasources.settings.datasources = [
      {
        name = "Thanos Query";
        type = "prometheus";
        url = "http://localhost:${toString catalog.services.thanos-query.port}";
        isDefault = true;
        jsonData = {
          timeInterval = "5s"; # node is scraping at 5s
        };
      }
      {
        name = "Prometheus";
        type = "prometheus";
        url = "http://localhost:${toString config.services.prometheus.port}";
        jsonData = {
          timeInterval = "5s"; # node is scraping at 5s
        };
      }
      {
        name = "VictoriaMetrics";
        type = "prometheus";
        url =
          "http://localhost:${toString catalog.services.victoriametrics.port}";
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

