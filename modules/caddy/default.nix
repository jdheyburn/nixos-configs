{ catalog, config, pkgs, lib, ... }:

with lib;

let

  cfg = config.modules.caddy;

  caddyMetricsPort = 2019;

  routeHandler =
    { port, upstream ? "localhost", skip_tls_verify ? false, path ? [ ] }:
    let
      base_handle = {
        handler = "reverse_proxy";
        upstreams = [{ dial = "${upstream}:${toString port}"; }];
      };
      handle = base_handle // optionalAttrs (skip_tls_verify) {
        transport = {
          protocol = "http";
          tls.insecure_skip_verify = true;
        };
      };
    in
    {
      handle = [ handle ];
    } // optionalAttrs (length path > 0) { match = [{ path = path; }]; };

  route =
    { name
    , port
    , upstream ? "localhost"
    , skip_tls_verify ? false
    , paths ? [ ]
    }:
    let
      subroutes = map (service: routeHandler service) (paths ++ [{
        port = port;
        upstream = upstream;
        skip_tls_verify = skip_tls_verify;
      }]);

    in
    {
      match = [{ host = [ "${name}.svc.joannet.casa" ]; }];
      terminal = true;
      handle = [{
        handler = "subroute";
        routes = subroutes;
      }];
    };

  # Filters out any services destined for this host, where we want it caddified
  # TODO should it also depend whether the module is enabled or not?
  host_services = attrValues (filterAttrs
    (svc_name: svc_def:
      svc_def ? "host" && svc_def.host.hostName == config.networking.hostName
      && svc_def.caddify.enable)
    catalog.services);

  # Now feed them into the route function to construct a route entry
  catalog_routes = map
    (service:
      route {
        name = service.name;
        port = service.port;
        skip_tls_verify = service.caddify ? "skip_tls_verify"
          && service.caddify.skip_tls_verify;
        paths = optionals (service.caddify ? "paths") service.caddify.paths;
      })
    host_services;

  # These are additional services that this host should forward
  forward_services = attrValues (filterAttrs
    (n: v:
      v ? "caddify" && v.caddify ? "forwardTo" && v.caddify.enable
      && v.caddify.forwardTo.hostName == config.networking.hostName)
    catalog.services);

  forward_routes = map
    (service:
      route {
        name = service.name;
        port = service.port;
        upstream = service.host.ip.private;
        skip_tls_verify = service.caddify ? "skip_tls_verify"
          && service.caddify.skip_tls_verify;
        # Not supporting paths yet since I don't have a scenario to test it on
      })
    forward_services;

  combined_routes = catalog_routes ++ forward_routes;

  subject_names = map (service: "${service.name}.svc.joannet.casa")
    (host_services ++ forward_services);

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
      ../../secrets/caddy-environment-file.age;

    services.caddy = {
      enable = true;
      package = (pkgs.callPackage ./custom-caddy.nix {
        plugins = [ "github.com/caddy-dns/cloudflare" ];
      });
      adapter = "''";
      # https://github.com/NixOS/nixpkgs/issues/153142
      configFile = pkgs.writeText "Caddyfile" (builtins.toJSON {
        logging.logs.default.level = "ERROR";
        apps = {
          http.servers.srv0 = {
            listen = [ ":443" ];
            routes = combined_routes;
          };
          tls.automation.policies = [{
            subjects = subject_names;
            issuers = [
              {
                module = "acme";
                ca = "https://acme-v02.api.letsencrypt.org/directory";
                challenges.dns.provider = {
                  name = "cloudflare";
                  api_token = "{env.CLOUDFLARE_API_TOKEN}";
                };
              }
              {
                module = "zerossl";
                ca = "https://acme-v02.api.letsencrypt.org/directory";
                challenges.dns.provider = {
                  name = "cloudflare";
                  api_token = "{env.CLOUDFLARE_API_TOKEN}";
                };
              }
            ];
          }];
        };
      });
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

