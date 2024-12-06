{ catalog, config, pkgs, lib, ... }:
with lib;
let cfg = config.modules.prometheusStack;
in {
  options.modules.prometheusStack = {
    blackbox.enable = mkEnableOption "Enable blackbox monitoring";
  };


  config = mkIf (cfg.enable && cfg.blackbox.enable) {

    services.prometheus.exporters = {
      node = {
        enable = true;
        port = catalog.services.nodeExporter.port;
      };
      blackbox = {
        enable = true;
        port = catalog.services.blackboxExporter.port;
        configFile = pkgs.writeText "blackbox.json" (builtins.toJSON {
          modules.http_2xx = {
            prober = "http";
            timeout = "5s";
            http.fail_if_not_ssl = true;
            http.preferred_ip_protocol = "ip4";
            # 401 and 403 because this is what minio and plex return
            # TODO investigate a blackbox on each node for TLS services
            # where their TLS port is not open
            http.valid_status_codes = [ 200 401 403 ];
          };
          modules.tls_connect = {
            prober = "tcp";
            timeout = "5s";
            tcp.tls = true;
          };
        });
      };
    };
  };
}
