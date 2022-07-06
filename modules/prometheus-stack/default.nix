{ config, pkgs, lib, ... }:

with lib;

let
  cfg = config.modules.prometheusStack;

  grafanaPort = 2342;
  lokiPort = 3100;
  nodeExporterPort = 9002;
  prometheusPort = 9001;
  nodeExporterTargets = [
    "dee.joannet.casa"
    "dennis.joannet.casa"
    "frank.joannet.casa"
    "paddys.joannet.casa"
  ];
in {
  options.modules.prometheusStack = {
    enable = mkEnableOption "Deploy Prometheus suite";
  };

  config = mkIf cfg.enable {

    networking.firewall.allowedTCPPorts =
      [ prometheusPort grafanaPort lokiPort ];

    services.grafana = {
      enable = true;
      domain = "grafana.svc.joannet.casa";
      port = grafanaPort;
      addr = "0.0.0.0";
      analytics.reporting.enable = false;

      declarativePlugins = with pkgs.grafanaPlugins; [ grafana-piechart-panel ];

      provision = {
        enable = true;
        datasources = [
          {
            name = "Prometheus";
            type = "prometheus";
            url = "http://localhost:${toString prometheusPort}";
            isDefault = true;
            jsonData = {
              timeInterval = "5s"; # node is scraping at 5s
            };
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
          port = nodeExporterPort;
        };
        blackbox = {
          enable = true;
          configFile = ./blackbox.yaml;
        };
      };
      scrapeConfigs = [
        # Scrape self
        {
          job_name = "prometheus";
          scrape_interval = "5s";
          static_configs =
            [{ targets = [ "localhost:${toString prometheusPort}" ]; }];
        }
        {
          job_name = "node";
          scrape_interval = "5s";
          static_configs = [{
            targets = map (node:
              "${node}:${
                toString config.services.prometheus.exporters.node.port
              }") nodeExporterTargets;
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
              regex =
                "(.*);(.*);(.*)"; # first is the url, thus unique for instance
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
      ];
    };

    services.loki = {
      enable = true;
      #configFile = ./loki-local-config.yaml;
      configuration = {
        auth_enabled = false;
        server.http_listen_port = 3100;
        compactor = {
          working_directory = "/var/lib/loki";
          shared_store = "filesystem";
          compactor_ring.kvstore.store = "inmemory";
        };

        ingester = {
          lifecycler = {
            address = "0.0.0.0";
            ring = {
              kvstore.store = "inmemory";
              replication_factor = 1;
            };
            final_sleep = "0s";
          };
          chunk_idle_period =
            "1h"; # Any chunk not receiving new logs in this time will be flushed
          max_chunk_age =
            "1h"; # All chunks will be flushed when they hit this age, default is 1h;
          chunk_target_size =
            1048576; # Loki will attempt to build chunks up to 1.5MB, flushing first if chunk_idle_period or max_chunk_age is reached first
          chunk_retain_period =
            "30s"; # Must be greater than index read cache TTL if using an index cache (Default index read cache TTL is 5m)
          max_transfer_retries = 0; # Chunk transfers disabled
        };

        schema_config = {
          configs = [{
            from = "2020-10-24";
            store = "boltdb-shipper";
            object_store = "filesystem";
            schema = "v11";
            index = {
              prefix = "index_";
              period = "24h";
            };
          }];
        };

        storage_config = {
          boltdb_shipper = {
            active_index_directory = "/var/lib/loki/boltdb-shipper-active";
            cache_location = "/var/lib/loki/boltdb-shipper-cache";
            cache_ttl =
              "24h"; # Can be increased for faster performance over longer query periods, uses more disk space
            shared_store = "filesystem";
          };
          filesystem.directory = "/var/lib/loki/chunks";
        };

        limits_config = {
          reject_old_samples = true;
          reject_old_samples_max_age = "168h";
        };

        chunk_store_config.max_look_back_period = "0s";

        table_manager = {
          retention_deletes_enabled = false;
          retention_period = "0s";
        };
      };
    };
  };

}
