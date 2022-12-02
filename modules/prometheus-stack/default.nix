{ catalog, config, pkgs, lib, ... }:

with lib;

let cfg = config.modules.prometheusStack;
in {
  options.modules.prometheusStack = {
    # TODO the string passed to these should be something simple as it gets appended to 'Whether to enable '
    enable = mkEnableOption "Deploy Prometheus suite";
  };

  config = mkIf cfg.enable {

    networking.firewall.allowedTCPPorts = [
      # TODO are all these still required after being fronted by local reverse proxy?
      config.services.grafana.settings.server.http_port
      config.services.loki.configuration.server.http_listen_port
      config.services.prometheus.port
    ];

    age.secrets."smtp-password" = {
      file = ../../secrets/smtp-password.age;
      owner = "grafana";
      group = "grafana";
    };

    age.secrets."thanos-objstore-config" = {
      file = ../../secrets/thanos-objstore-config.age;
      # TODO thanos-store systemd runs as DynamicUser
      # see if we can set it to a known user, maybe prometheus
      # and then change the owner of this file to that
      mode = "0444";
    };

    services.grafana = import ./grafana.nix { inherit catalog config pkgs; };
    services.loki = import ./loki.nix { inherit catalog pkgs; };
    services.prometheus =
      import ./prometheus.nix { inherit catalog config pkgs lib; };
    services.thanos = import ./thanos.nix { inherit catalog config pkgs; };
  };
}
