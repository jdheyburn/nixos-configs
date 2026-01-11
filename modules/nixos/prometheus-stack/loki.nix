{ catalog, config, pkgs, lib, utils, ... }:

with lib;

let
  cfg = config.modules.prometheusStack;
  lokiDir = "/var/lib/loki";
in
{
  options.modules.prometheusStack.loki.enable = mkEnableOption "Deploy Loki";

  config = mkIf (cfg.enable && cfg.loki.enable)
    {
      services.caddy.virtualHosts."loki.${catalog.domain.service}".extraConfig =
        utils.caddy.mkServiceVHost {
          port = catalog.services.loki.port;
        };

      services.loki = {
        enable = true;
        configuration = {
          auth_enabled = false;
          server.http_listen_port = catalog.services.loki.port;
          compactor = {
            working_directory = lokiDir;
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
            # Any chunk not receiving new logs in this time will be flushed
            chunk_idle_period = "1h";
            # All chunks will be flushed when they hit this age, default is 1h;
            max_chunk_age = "1h";
            # Loki will attempt to build chunks up to 1.5MB, flushing first if chunk_idle_period or max_chunk_age is reached first
            chunk_target_size = 1048576;
            # Must be greater than index read cache TTL if using an index cache (Default index read cache TTL is 5m)
            chunk_retain_period = "30s";
          };

          schema_config = {
            configs = [
              {
                from = "2024-12-06";
                store = "tsdb";
                object_store = "filesystem";
                schema = "v13";
                index = {
                  prefix = "index_";
                  period = "24h";
                };
              }
            ];
          };

          storage_config = {
            tsdb_shipper = {
              active_index_directory = "${lokiDir}/tsdb-index";
              cache_location = "${lokiDir}/tsdb-cache";
              # Can be increased for faster performance over longer query periods, uses more disk space
              cache_ttl = "24h";
            };
            filesystem.directory = "${lokiDir}/chunks";
          };

          limits_config = {
            allow_structured_metadata = false;
            reject_old_samples = true;
            reject_old_samples_max_age = "168h";
          };

          table_manager = {
            retention_deletes_enabled = false;
            retention_period = "0s";
          };

          ruler = {
            storage = {
              type = "local";
              local.directory = "${lokiDir}/rules";
            };
          };
        };
      };

      services.restic.backups.small-files = {
        paths = [ lokiDir ];
      };
    };
}
