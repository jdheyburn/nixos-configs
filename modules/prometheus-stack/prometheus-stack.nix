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
        job_name = "dennis";
        static_configs = [{
          targets = [
            "127.0.0.1:${
              toString config.services.prometheus.exporters.node.port
            }"
          ];
        }];
      }
      {
        job_name = "dee";
        static_configs = [{
          targets = [
            "dee.joannet.casa:${
              toString config.services.prometheus.exporters.node.port
            }"
          ];
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

    ];
  };

  services.loki = {
    enable = true;
    configFile = ./loki-local-config.yaml;
  };

}
