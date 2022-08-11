{ catalog, config, pkgs, lib, ... }:

with lib;

let

  cfg = config.modules.caddy;

  caddyMetricsPort = 2019;

  # TODO move this to another file
  route = { name, port, upstream ? "localhost", skip_tls_verify ? false }:
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
    in {
      match = [{ host = [ "${name}.svc.joannet.casa" ]; }];
      terminal = true;
      handle = [{
        handler = "subroute";
        routes = [{ handle = [ handle ]; }];
      }];
    };

  # Filters out any services destined for this host, where we want it caddified
  # TODO should it also depend whether the module is enabled or not?
  host_services = (filterAttrs (n: v:
    hasAttr "host" v && v.host == config.networking.hostName
    && v.caddify.enable) catalog.services);

  # Convert host_routes to a list, including the name of the service in it too
  host_services_list = map (service_name:
    (getAttr service_name host_services) // {
      name = service_name;
    }) (attrNames host_services);

  # Now feed them into the route function to construct a route entry
  catalog_routes = map (service:
    route {
      name = service.name;
      port = service.port;
      skip_tls_verify = hasAttr "skip_tls_verify" service.caddify
        && service.caddify.skip_tls_verify;
    }) host_services_list;

  # These are additional services that this host should forward
  forward_services = (filterAttrs (n: v:
    hasAttr "caddify" v && hasAttr "forwardTo" v.caddify && v.caddify.enable && v.caddify.forwardTo == config.networking.hostName) catalog.services);

  # Convert it to a list
  forward_services_list = map (service_name:
    (getAttr service_name forward_services) // {
      name = service_name;
    }) (attrNames forward_services);

  forward_routes = map (service:
    route {
      name = service.name;
      port = service.port;
      upstream = (getAttr service.host catalog.nodes).ip.private;
      skip_tls_verify = hasAttr "skip_tls_verify" service.caddify && service.caddify.skip_tls_verify;
    }) forward_services_list;

  combined_routes = catalog_routes ++ forward_routes;

  subject_routes =
    map (service: "${service.name}.svc.joannet.casa") (host_services_list ++ forward_services_list);

in {

  options = {
    modules = {
      caddy = {
        enable = mkEnableOption "Deploy reverse proxy Caddy";
        forward_additional = mkEnableOption "Whether to forward additional services in caddy";
        };
    };
  };

  config = mkIf cfg.enable {

    networking.firewall.allowedTCPPorts = [
      80 # Caddy
      443 # Caddy
      caddyMetricsPort
    ];

    age.secrets."caddy-environment-file".file =
      ../../secrets/caddy-environment-file.age;

    # TODO I should have a reverse proxy on every host, 
    # reversing every service on it
    # just because I do maint on caddy server (dee) should not 
    # mean I lose access to services running elsewhere
    services.caddy = {
      enable = true;
      package = (pkgs.callPackage ./custom-caddy.nix {
        plugins = [ "github.com/caddy-dns/cloudflare" ];
        vendorSha256 = "sha256-HrUARAM0/apr+ijSousglLYgxVNy9SFW6MhWkSeTFU4=";
      });
      #configFile = ./Caddyfile;
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
            subjects = subject_routes;
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
      };
    };

  };

}

