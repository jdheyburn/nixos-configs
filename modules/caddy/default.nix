{ config, pkgs, lib, ... }:

with lib;

let

  cfg = config.modules.caddy;

  caddyMetricsPort = 2019;
in {

  options = {
    modules = {
      caddy = { enable = mkEnableOption "Deploy reverse proxy Caddy"; };
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
      #      configFile = ./Caddyfile;
      adapter = "''";
      configFile = pkgs.writeText "Caddyfile" (builtins.toJSON {
        logging.logs.default.level = "ERROR";
        apps = {
          http.servers.srv0 = {
            listen = [ ":443" ];
            routes = [
              {
                match = [{ host = [ "prometheus.svc.joannet.casa" ]; }];
                terminal = true;
                handle = [{
                  handler = "subroute";
                  routes = [{
                    handle = [{
                      handler = "reverse_proxy";
                      upstreams = [{ dial = "dennis.joannet.casa:9001"; }];
                    }];
                  }];
                }];
              }
              {
                match = [{ host = [ "portainer.svc.joannet.casa" ]; }];
                terminal = true;
                handle = [{
                  handler = "subroute";
                  routes = [{
                    handle = [{
                      handler = "reverse_proxy";
                      upstreams = [{ dial = "frank.joannet.casa:9000"; }];
                    }];
                  }];
                }];
              }
              {
                match = [{ host = [ "navidrome.svc.joannet.casa" ]; }];
                terminal = true;
                handle = [{
                  handler = "subroute";
                  routes = [{
                    handle = [{
                      handler = "reverse_proxy";
                      upstreams = [{ dial = "dee.joannet.casa:4533"; }];
                    }];
                  }];
                }];
              }
              {
                match = [{ host = [ "adguard.svc.joannet.casa" ]; }];
                terminal = true;
                handle = [{
                  handler = "subroute";
                  routes = [{
                    handle = [{
                      handler = "reverse_proxy";
                      upstreams = [{ dial = "localhost:3000"; }];
                    }];
                  }];
                }];
              }
              {
                match = [{ host = [ "proxmox.svc.joannet.casa" ]; }];
                terminal = true;
                handle = [{
                  handler = "subroute";
                  routes = [{
                    handle = [{
                      handler = "reverse_proxy";
                      transport = {
                        protocol = "http";
                        tls.insecure_skip_verify = true;
                      };
                      upstreams = [{ dial = "pve0.joannet.casa:8006"; }];
                    }];
                  }];
                }];
              }
              {
                match = [{ host = [ "grafana.svc.joannet.casa" ]; }];
                terminal = true;
                handle = [{
                  handler = "subroute";
                  routes = [{
                    handle = [{
                      handler = "reverse_proxy";
                      upstreams = [{ dial = "dennis.joannet.casa:2342"; }];
                    }];
                  }];
                }];
              }
              {
                match = [{ host = [ "huginn.svc.joannet.casa" ]; }];
                terminal = true;
                handle = [{
                  handler = "subroute";
                  routes = [{
                    handle = [{
                      handler = "reverse_proxy";
                      upstreams = [{ dial = "frank.joannet.casa:3000"; }];
                    }];
                  }];
                }];
              }
              {
                match = [{ host = [ "unifi.svc.joannet.casa" ]; }];
                terminal = true;
                handle = [{
                  handler = "subroute";
                  routes = [{
                    handle = [{
                      handler = "reverse_proxy";
                      transport = {
                        protocol = "http";
                        tls.insecure_skip_verify = true;
                      };
                      upstreams = [{ dial = "localhost:8443"; }];
                    }];
                  }];
                }];
              }
              {
                match = [{ host = [ "home.svc.joannet.casa" ]; }];
                terminal = true;
                handle = [{
                  handler = "subroute";
                  routes = [{
                    handle = [{
                      handler = "reverse_proxy";
                      upstreams = [{ dial = "frank.joannet.casa:49154"; }];
                    }];
                  }];
                }];
              }
              {
                match = [{ host = [ "plex.svc.joannet.casa" ]; }];
                terminal = true;
                handle = [{
                  handler = "subroute";
                  routes = [{
                    handle = [{
                      handler = "reverse_proxy";
                      upstreams = [{ dial = "dee.joannet.casa:32400"; }];
                    }];
                  }];
                }];
              }
              {
                match = [{ host = [ "loki.svc.joannet.casa" ]; }];
                terminal = true;
                handle = [{
                  handler = "subroute";
                  routes = [{
                    handle = [{
                      handler = "reverse_proxy";
                      upstreams = [{ dial = "dennis.joannet.casa:3100"; }];
                    }];
                  }];
                }];
              }
            ];
          };
          tls.automation.policies = [{
            subjects = [
              "prometheus.svc.joannet.casa"
              "portainer.svc.joannet.casa"
              "navidrome.svc.joannet.casa"
              "adguard.svc.joannet.casa"
              "proxmox.svc.joannet.casa"
              "grafana.svc.joannet.casa"
              "huginn.svc.joannet.casa"
              "unifi.svc.joannet.casa"
              "home.svc.joannet.casa"
              "plex.svc.joannet.casa"
              "loki.svc.joannet.casa"
            ];
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
