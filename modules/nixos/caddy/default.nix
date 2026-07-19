{ catalog, config, pkgs, lib, myUtils, ... }:

with lib;

let

  cfg = config.modules.caddy;

  caddyMetricsPort = 2019;

  thisHost = catalog.nodes.${config.networking.hostName};

  # Any service whose catalog entry lives on this host AND declares a
  # separate backendHost gets an auto-generated reverse proxy vhost.
  proxiedServices = attrValues (filterAttrs
    (name: svc: (svc ? host) && (svc ? backendHost) && svc.host == thisHost)
    catalog.services);
in
{

  options = {
    modules = {
      caddy = { enable = mkEnableOption "Deploy reverse proxy Caddy"; };
    };
  };

  config = mkIf cfg.enable {

    # Allow network access when building
    # https://mdleom.com/blog/2021/12/27/caddy-plugins-nixos/#xcaddy
    nix.settings.sandbox = false;

    networking.firewall.allowedTCPPorts = [
      80 # Caddy
      443 # Caddy
      caddyMetricsPort
    ];

    age.secrets."caddy-environment-file".file =
      myUtils.secrets.file "caddy-environment-file";

    services.caddy = {
      enable = true;
      package = pkgs.caddy.withPlugins {
        plugins = [ "github.com/caddy-dns/cloudflare@v0.2.4" ];
        hash = "sha256-7GoH8YLCoPmPExQxoga2FHB58zQDoZVf1BBwkVi0SsQ=";
      };
      virtualHosts = listToAttrs (map
        (svc: {
          name = "${svc.name}.${catalog.domain.service}";
          value.extraConfig = ''
            tls {
              dns cloudflare {env.CLOUDFLARE_API_TOKEN}
            }
            reverse_proxy ${svc.backendHost.ip.private}:${toString svc.port}
          '';
        })
        proxiedServices);
    };

    systemd.services.caddy = {
      serviceConfig = {
        # Required to use ports < 1024
        AmbientCapabilities = "cap_net_bind_service";
        CapabilityBoundingSet = "cap_net_bind_service";
        EnvironmentFile = config.age.secrets."caddy-environment-file".path;
        TimeoutStartSec = "5m";
      };
    };
  };
}
