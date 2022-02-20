{ config, pkgs, lib, ... }:

{ 

  networking.firewall = {
     allowedTCPPorts = [
       80  # Caddy
       443 # Caddy
     ];
   };


  services.caddy = {
    enable = true;
    package = (pkgs.callPackage ./custom-caddy.nix {
      plugins = [ "github.com/caddy-dns/cloudflare" ];
      vendorSha256 = "sha256-HrUARAM0/apr+ijSousglLYgxVNy9SFW6MhWkSeTFU4=";
    });
    extraConfig = ''
      unifi.svc.joannet.casa {
        tls {
          dns cloudflare {env.CLOUDFLARE_API_TOKEN}
        }
        reverse_proxy localhost:8443 {
          transport http {
            tls_insecure_skip_verify
          }
        }
      }
      adguard.svc.joannet.casa {
        tls {
          dns cloudflare {env.CLOUDFLARE_API_TOKEN}
        }
        reverse_proxy localhost:3000
      }
      portainer.svc.joannet.casa {
        tls {
          dns cloudflare {env.CLOUDFLARE_API_TOKEN}
        }
        reverse_proxy frank.joannet.casa:9000
      }
      home.svc.joannet.casa {
        tls {
          dns cloudflare {env.CLOUDFLARE_API_TOKEN}
        }
        reverse_proxy frank.joannet.casa:49154
      }
      huginn.svc.joannet.casa {
        tls {
          dns cloudflare {env.CLOUDFLARE_API_TOKEN}
        }
        reverse_proxy frank.joannet.casa:3000
      }
      proxmox.svc.joannet.casa {
        tls {
          dns cloudflare {env.CLOUDFLARE_API_TOKEN}
        }
        reverse_proxy pve0.joannet.casa:8006 {
          transport http {
            tls_insecure_skip_verify
          }
        }
      }
    '';
  };

  systemd.services.caddy = {
    environment = {
      CLOUDFLARE_API_TOKEN = (builtins.readFile /etc/nixos/secrets/cloudflare-api-token);
    };

    serviceConfig = {
      # Required to use ports < 1024
      AmbientCapabilities = "cap_net_bind_service";
      CapabilityBoundingSet = "cap_net_bind_service";
    };
  };


}
