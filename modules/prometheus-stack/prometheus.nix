{ catalog, config, pkgs }: {
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
  scrapeConfigs = [
    # Scrape self
    {
      job_name = "prometheus";
      scrape_interval = "5s";
      static_configs = [{
        targets = [ "localhost:${toString config.services.prometheus.port}" ];
      }];
    }
    {
      job_name = "grafana";
      scrape_interval = "5s";
      static_configs = [{
        targets = [ "localhost:${toString config.services.grafana.port}" ];
      }];
    }
    {
      job_name = "node";
      scrape_interval = "5s";
      static_configs = [{
        targets = map (node:
          "${node}:${toString config.services.prometheus.exporters.node.port}")
          catalog.nodeExporterTargets;
      }];
      # Convert instance label "<hostname>:<port>" -> "<hostname>"
      # https://stackoverflow.com/questions/49896956/relabel-instance-to-hostname-in-prometheus
      relabel_configs = [{
        source_labels = [ "__address__" ];
        target_label = "instance";
        regex = "([^:]+)(:[0-9]+)?";
        replacement = "\${1}";
      }];
    }
    {
      job_name = "unifi";
      static_configs = [{
        targets = [
          "dee.joannet.casa:${
            toString config.services.prometheus.exporters.unifi-poller.port
          }"
        ];
      }];
    }
    {
      job_name = "caddy";
      static_configs = [{ targets = [ "dee.joannet.casa:2019" ]; }];
    }
    # {
    #   job_name = "adguard";
    #   static_configs = [{ targets = [ "dee.joannet.casa:9617" ]; }];
    # }
    {
      # Inspiration from:
      #   https://github.com/prometheus/blackbox_exporter#prometheus-configuration
      #   https://github.com/maxandersen/internet-monitoring/blob/master/prometheus/prometheus.yml
      job_name = "blackbox";
      metrics_path = "/probe";
      params = { module = [ "http_2xx" "tls_connect" ]; };
      static_configs = [{
        # TODO internal targets should be discovered from catalog.services
        targets = [
          "https://google.com;google.com;external"
          "https://github.com;github.com;external"
          "https://bbc.co.uk;bbc.co.uk;external"
          "https://adguard.svc.joannet.casa;adguard;internal"
          "https://grafana.svc.joannet.casa;grafana;internal"
          "https://home.svc.joannet.casa;heimdall;internal"
          "https://huginn.svc.joannet.casa;huginn;internal"
          "https://portainer.svc.joannet.casa;portainer;internal"
          "https://prometheus.svc.joannet.casa;prometheus;internal"
          "https://proxmox.svc.joannet.casa;proxmox;internal"
          "https://unifi.svc.joannet.casa;unifi;internal"
        ];
      }];
      relabel_configs = [
        {
          source_labels = [ "__address__" ];
          regex = "(.*);(.*);(.*)"; # first is the url, thus unique for instance
          target_label = "instance";
          replacement = "$1";
        }
        {
          source_labels = [ "__address__" ];
          regex = "(.*);(.*);(.*)"; # second is humanname to use in charts
          target_label = "humanname";
          replacement = "$2";
        }
        {
          source_labels = [ "__address__" ];
          regex =
            "(.*);(.*);(.*)"; # third state whether this is testing external or internal network
          target_label = "routing";
          replacement = "$3";
        }
        {
          source_labels = [ "instance" ];
          target_label = "__param_target";
        }
        {
          target_label = "__address__";
          replacement = "127.0.0.1:9115";
        }
      ];
    }
    {
      job_name = "minio";
      metrics_path = "/minio/v2/metrics/cluster";
      scheme = "https";
      static_configs = [{ targets = [ "minio.svc.joannet.casa" ]; }];
    }
  ];
}

