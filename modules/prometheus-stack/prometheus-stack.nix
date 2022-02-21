{ config, pkgs, lib, ... }:

with lib;

let grafanaPort = 2342;
in {

  networking.firewall.allowedTCPPorts = [ grafanaPort ];

  services.grafana = {
    enable = true;
    domain = "grafana.svc.joannet.casa";
    port = grafanaPort;
    addr = "0.0.0.0";
  };

  services.prometheus = {
    enable = true;
    port = 9001;
    exporters = {
      node = {
        enable = true;
        enabledCollectors = [ "systemd" ];
        port = 9002;
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

    ];
  };

  services.loki = {
    enable = true;
    configFile = ./loki-local-config.yaml;
  };

  services.promtail = {
    enable = true;
    configuration = {
      server = {
        http_listen_port = 28183;
        grpc_listen_port = 0;
      };
      positions = { filename = "/tmp/positions.yaml"; };
      clients = [{ url = "http://dennis.joannet.casa:3100/loki/api/v1/push"; }];
      scrape_configs = [{
        job_name = "journal";
        journal = {
          max_age = "12h";
          labels = {
            job = "systemd-journal";
            host = "dennis";
          };
        };
        relabel_configs = [{
          source_labels = [ "__journal__systemd_unit" ];
          target_label = "unit";
        }];
      }];
    };
  };

  # systemd.services.promtail = {
  #   description = "Promtail service for Loki";
  #   wantedBy = [ "multi-user.target" ];

  #   serviceConfig = {
  #     ExecStart = ''
  #       ${pkgs.grafana-loki}/bin/promtail --config.file ${./promtail.yaml}
  #     '';
  #   };
  # };
}
