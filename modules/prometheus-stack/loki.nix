{ catalog, pkgs }:

let lokiDir = "/var/lib/loki";
in {
  enable = false;
  configuration = {
    auth_enabled = false;
    server.http_listen_port = catalog.services.loki.port;
    compactor = {
      working_directory = lokiDir;
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
      # Any chunk not receiving new logs in this time will be flushed
      chunk_idle_period = "1h";
      # All chunks will be flushed when they hit this age, default is 1h;
      max_chunk_age = "1h";
      # Loki will attempt to build chunks up to 1.5MB, flushing first if chunk_idle_period or max_chunk_age is reached first
      chunk_target_size = 1048576;
      # Must be greater than index read cache TTL if using an index cache (Default index read cache TTL is 5m)
      chunk_retain_period = "30s";
      # Chunk transfers disabled
      max_transfer_retries = 0;
    };

    schema_config = {
      configs = [
        {
          from = "2020-10-24";
          store = "boltdb-shipper";
          object_store = "filesystem";
          schema = "v11";
          index = {
            prefix = "index_";
            period = "24h";
          };
        }
        {
          from = "2023-03-09";
          store = "tsdb";
          object_store = "filesystem";
          schema = "v12";
          index = {
            prefix = "index_";
            period = "24h";
          };
        }
      ];
    };

    storage_config = {
      boltdb_shipper = {
        active_index_directory = "${lokiDir}/boltdb-shipper-active";
        cache_location = "${lokiDir}/boltdb-shipper-cache";
        # Can be increased for faster performance over longer query periods, uses more disk space
        cache_ttl = "24h";
        shared_store = "filesystem";
      };
      tsdb_shipper = {
        active_index_directory = "${lokiDir}/tsdb-index";
        cache_location = "${lokiDir}/tsdb-cache";
        # Can be increased for faster performance over longer query periods, uses more disk space
        cache_ttl = "24h";
        shared_store = "filesystem";
      };
      filesystem.directory = "${lokiDir}/chunks";
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

    ruler = {
      storage = {
        type = "local";
        local.directory = "${lokiDir}/rules";
      };
    };
  };
}

