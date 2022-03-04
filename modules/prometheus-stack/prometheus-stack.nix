{ config, pkgs, lib, ... }:

with lib;

let
  grafanaPort = 2342;
  lokiPort = 3100;
  nodeExporterPort = 9002;
  prometheusPort = 9001;
  nodeExporterTargets = [ "dee.joannet.casa" "dennis.joannet.casa" "frank.joannet.casa" "paddys.joannet.casa" ];
in {

  imports = [ ../promtail.nix ];

  networking.firewall.allowedTCPPorts = [ prometheusPort grafanaPort lokiPort ];

  services.grafana = {
    enable = true;
    domain = "grafana.svc.joannet.casa";
    port = grafanaPort;
    addr = "0.0.0.0";

    declarativePlugins = with pkgs.grafanaPlugins; [ grafana-piechart-panel ];

    provision = {
      enable = true;
      datasources = [
        {
          name = "Prometheus";
          type = "prometheus";
          url = "http://localhost:${toString prometheusPort}";
          isDefault = true;
        }
        {
          name = "Loki";
          type = "loki";
          url = "http://localhost:${toString lokiPort}";
        }
      ];
    };
  };

  services.prometheus = {
    enable = true;
    port = prometheusPort;
    exporters = {
      node = {
        enable = true;
        enabledCollectors = [ "systemd" ];
        port = nodeExporterPort;
      };
      blackbox = {
        enable = true;
        configFile = ./blackbox.yaml;
      };
    };
    scrapeConfigs = [
      {
        job_name = "node";
        static_configs = [{
          targets = map (node:
            "${node}:${toString config.services.prometheus.exporters.node.port}")
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
      {
        # Inspiration from:
        #   https://github.com/prometheus/blackbox_exporter#prometheus-configuration
        #   https://github.com/maxandersen/internet-monitoring/blob/master/prometheus/prometheus.yml
        job_name = "blackbox";
        metrics_path = "/probe";
        params = {
          module = [ "http_2xx" ];
        };
        static_configs = [{
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
        relabel_configs = [{
            source_labels = ["__address__"]; 
            regex= "(.*);(.*);(.*)";  # first is the url, thus unique for instance
            target_label = "instance"; 
            replacement = "$1";
            }
            {
              source_labels = ["__address__"]; 
            regex= "(.*);(.*);(.*)";  # second is humanname to use in charts
            target_label = "humanname"; 
            replacement = "$2";
            }
            {
              source_labels = ["__address__"]; 
            regex= "(.*);(.*);(.*)";  # third state whether this is testing external or internal network
            target_label = "routing"; 
            replacement = "$3";
            }
            {
              target_label = "__address__";
              replacement = "127.0.0.1:9115";
            }
        ];   
      }
    ];
  };

  services.loki = {
    enable = true;
    configFile = ./loki-local-config.yaml;
  };

}
