{ catalog, config, lib, myUtils, ... }:

with lib;

let
  cfg = config.modules.unifi-proxy;

  svc = catalog.services.unifi;
in
{

  options = {
    modules = {
      unifi-proxy = {
        enable = mkEnableOption "Reverse proxy to the UniFi Cloud Gateway";
      };
    };
  };

  # Publishes a Caddy vhost that reverse proxies to the UniFi Cloud Gateway
  # (a separate physical device, not the self-hosted `unifi` container module).
  # Requires the `caddy` module to be enabled on the same host.
  config = mkIf cfg.enable {

    services.caddy.virtualHosts."${svc.name}.${catalog.domain.service}".extraConfig = ''
      ${myUtils.caddy.cloudflareTLS false}
      reverse_proxy https://${svc.backendHost.ip.private}:${toString svc.port} {
          transport http {
              tls_insecure_skip_verify
          }
          # UniFi OS validates the WebSocket Origin against the backend's own
          # address; rewrite it so /api/ws/* upgrades aren't rejected with a
          # 500 when proxied behind this vhost.
          header_up Origin https://{upstream_hostport}
      }
    '';
  };
}
