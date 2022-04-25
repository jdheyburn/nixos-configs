

{ config, pkgs, lib, ... }:

with lib;

let
  cfg = config.modules.promtail;

  promtailPort = 28183;
in {

  options.modules.promtail = {
    enable = mkOption {
      type = types.bool;
      default = false;
    };
  };

  config = mkIf cfg.enable {

    networking.firewall.allowedTCPPorts = [ promtailPort ];

    services.promtail = {
      enable = true;
      configuration = {
        server = {
          http_listen_port = promtailPort;
          grpc_listen_port = 0;
        };
        positions = { filename = "/tmp/positions.yaml"; };
        clients =
          [{ url = "http://dennis.joannet.casa:3100/loki/api/v1/push"; }];
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

  };
}
