# Catalog defines the systems & services on my network.
# Inspired from https://github.com/jhillyerd/homelab/blob/main/nixos/catalog.nix
{ lib, system }:
with lib;

rec

{

  nodes = {
    dee = {
      ip.private = "192.168.1.10";
      ip.tailscale = "100.127.189.33";
      system = system.aarch64-linux;
    };

    dennis = {
      ip.private = "192.168.1.12";
      ip.tailscale = "100.127.102.123";
      system = system.x86_64-linux;
    };

    frank = {
      ip.private = "192.168.1.11";
      ip.tailscale = "100.71.206.55";
    };

    paddys = {
      ip.private = "192.168.1.20";
      ip.tailscale = "100.107.150.109";
    };

    pve0 = {
      ip.private = "192.168.1.15";
      ip.tailscale = "100.80.112.68";
    };
  };

  nodeExporterTargets =
    map (node_name: "${node_name}.joannet.casa") (attrNames nodes);

  services = {
    adguard = {
      host = "dee";
      port = 3000;
      caddify.enable = true;
    };

    home = {
      host = "frank";
      port = 49154;
      blackbox_name = "heimdall";
      caddify.enable = true;
      caddify.forwardTo = "dee";
    };

    huginn = {
      host = "frank";
      port = 3000;
      caddify.enable = true;
      caddify.forwardTo = "dee";
    };

    grafana = {
      host = "dennis";
      port = 2342;
      caddify.enable = true;
    };

    loki = {
      host = "dennis";
      port = 3100;
      caddify.enable = true;
    };

    nodeExporter = { port = 9002; };

    minio = {
      host = "dee";
      port = 9100;
      consolePort = 9101;
      caddify.enable = true;
    };

    "ui.minio" = {
      host = "dee";
      port = services.minio.consolePort;
      caddify.enable = true;
    };

    portainer = {
      host = "frank";
      port = 9000;
      caddify.enable = true;
      caddify.forwardTo = "dee";
    };

    prometheus = {
      host = "dennis";
      port = 9001;
      caddify.enable = true;
    };

    proxmox = {
      host = "pve0";
      port = 8006;
      caddify.enable = true;
      caddify.skip_tls_verify = true;
      caddify.forwardTo = "dee";
    };

    plex = {
      host = "dee";
      port = 32400;
      caddify.enable = true;
    };

    thanos-query = {
      host = "dennis";
      port = 19192;
      grpcPort = 10902;
      caddify.enable = true;
    };

    thanos-sidecar = {
      port = 19191;
      grpcPort = 10901;
    };

    thanos-store = {
      port = 19193;
      grpcPort = 10903;
    };

    unifi = {
      host = "dee";
      port = 8443;
      caddify.enable = true;
      caddify.skip_tls_verify = true;
    };

    victoriametrics = {
      host = "dennis";
      port = 8428;
      caddify.enable = true;
    };
  };

  # TODO don't repeat this from prometheus.nix
  prometheusScrapeConfigs = [
    # Scrape self
    {
      job_name = "prometheus";
      scrape_interval = "5s";
      static_configs =
        [{ targets = [ "localhost:${toString services.prometheus.port}" ]; }];
    }
    {
      job_name = "grafana";
      scrape_interval = "5s";
      static_configs =
        [{ targets = [ "localhost:${toString services.grafana.port}" ]; }];
    }
    {
      job_name = "node";
      scrape_interval = "5s";
      static_configs = [{
        targets = map (node: "${node}:${toString services.nodeExporter.port}")
          nodeExporterTargets;
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
      static_configs = [{ targets = [ "dee.joannet.casa:9130" ]; }];
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

