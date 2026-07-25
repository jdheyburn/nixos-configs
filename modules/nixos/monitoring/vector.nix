{ catalog, config, pkgs, lib, ... }:

with lib;

let cfg = config.modules.vector;
in {

  options.modules.vector = {
    enable = mkOption {
      type = types.bool;
      default = false;
    };
  };

  config = mkIf cfg.enable {

    networking.firewall.allowedTCPPorts = [ catalog.services.vector.port ];

    services.vector = {
      enable = true;
      # adds the systemd-journal supplementary group to the unit
      journaldAccess = true;
      settings = {
        sources.journald = {
          type = "journald";
          # Loki rejects samples older than 168h, and there is no pre-existing
          # history in Loki to preserve, so start from now rather than
          # backfilling the whole journal on first start.
          since_now = true;
          current_boot_only = false;
        };

        sources.internal_metrics.type = "internal_metrics";

        # endpoint is a base URL; the sink appends its `path`, which defaults
        # to /loki/api/v1/push
        sinks.loki = {
          type = "loki";
          inputs = [ "journald" ];
          endpoint = "https://loki.${catalog.domain.service}";
          encoding.codec = "text";
          labels = {
            job = "systemd-journal";
            host = config.networking.hostName;
            unit = "{{ _SYSTEMD_UNIT }}";
          };
        };

        sinks.vector_metrics = {
          type = "prometheus_exporter";
          inputs = [ "internal_metrics" ];
          address = "0.0.0.0:${toString catalog.services.vector.port}";
        };
      };
    };
  };
}
