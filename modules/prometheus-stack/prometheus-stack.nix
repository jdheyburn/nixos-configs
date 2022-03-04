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

  networking.firewall.allowedTCPPorts = [ grafanaPort lokiPort ];

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
        job_name = "blackbox";
        metrics_path = "/probe";
        params = {
          module = [ "http_2xx" "tls_connect" ];
        };
        static_configs = [{
          targets = [
            "https://adguard.svc.joannet.casa"
            "https://grafana.svc.joannet.casa"
            "https://home.svc.joannet.casa"
            "https://huginn.svc.joannet.casa"
            "https://loki.svc.joannet.casa"
            "https://portainer.svc.joannet.casa"
            "https://proxmox.svc.joannet.casa"
            "https://unifi.svc.joannet.casa"
          ];
        }];
        relabel_configs = [{
          {
            source_labels = ["__address__"]; 
            target_label = "__param_target"; 
            }
            {
              source_labels = ["__param_target"];
              target_label = "instance";
            }
        }];   
      }
    ];
  };

  services.loki = {
    enable = true;
    configFile = ./loki-local-config.yaml;
  };

}
