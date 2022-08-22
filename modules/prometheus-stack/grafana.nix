{ catalog, config, pkgs }:

{
  enable = true;
  rootUrl = "https://grafana.svc.joannet.casa";
  port = catalog.services.grafana.port;
  addr = "0.0.0.0";
  analytics.reporting.enable = false;

  declarativePlugins = with pkgs.grafanaPlugins; [ grafana-piechart-panel ];

  provision = {
    enable = true;
    datasources = [
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
    # Not sure if this actually works.. the datasource provision above works for existing deployments
    # TODO
    notifiers = [{
      name = "email-me";
      uid = "email-me";
      type = "email";
      is_default = true;
      disable_resolve_message = false;
      settings = { addresses = "jdheyburn@gmail.com"; };
    }];
  };

  smtp = {
    enable = true;
    host = "smtp.gmail.com:587";
    user = "jdheyburn@gmail.com";
    passwordFile = config.age.secrets."smtp-password".path;
  };
}

