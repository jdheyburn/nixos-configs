

{ catalog, config, pkgs, lib, ... }:

with lib;

let cfg = config.modules.promtail;
in {

  options.modules.promtail = {
    enable = mkOption {
      type = types.bool;
      default = false;
    };
  };

  config = mkIf cfg.enable {

    networking.firewall.allowedTCPPorts = [ catalog.services.promtail.port ];

    services.promtail = {
      enable = true;
      configuration = {
        server = {
          http_listen_port = catalog.services.promtail.port;
          grpc_listen_port = 0;
        };
        positions = { filename = "/tmp/positions.yaml"; };
        clients = [{ url = "https://loki.svc.joannet.casa/loki/api/v1/push"; }];
        scrape_configs = [{
          job_name = "journal";
          journal = {
            max_age = "12h";
            labels = {
              job = "systemd-journal";
              host = "${config.networking.hostName}";
            };
          };
          relabel_configs = [{
            source_labels = [ "__journal__systemd_unit" ];
            target_label = "unit";
          }];
        }];
      };
    };

    systemd.services.promtail.serviceConfig.TimeoutStartSec = "5m";
  };
}
