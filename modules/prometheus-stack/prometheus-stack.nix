{ config, pkgs, lib, ... }:

with lib;

let
  grafanaPort = 2342;
  lokiPort = 3100;
  nodeExporterPort = 9002;
  prometheusPort = 9001;
in {

  imports = [ ../promtail.nix ];

  networking.firewall.allowedTCPPorts = [ grafanaPort lokiPort ];

  services.grafana = {
    enable = true;
    domain = "grafana.svc.joannet.casa";
    port = grafanaPort;
    addr = "0.0.0.0";

    declarativePlugins = with pkgs.grafanaPlugins; [ grafana-piechart-panel ];
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
          targets = [
            "dennis.joannet.casa:${
              toString config.services.prometheus.exporters.node.port
            }"
            "dee.joannet.casa:${
              toString config.services.prometheus.exporters.node.port
            }"
          ];
        }];
        # https://stackoverflow.com/questions/49896956/relabel-instance-to-hostname-in-prometheus
        relabel_configs = [{
          source_labels = ["__address__"];
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
        static_configs = [{
          targets = [
            "dee.joannet.casa:2019"
          ];
        }];
      }

    ];
  };

  services.loki = {
    enable = true;
    configFile = ./loki-local-config.yaml;
  };

}
