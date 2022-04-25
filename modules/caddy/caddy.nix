{ config, pkgs, lib, ... }:

with lib;

let

  cfg = config.modules.caddy;

  caddyMetricsPort = 2019;
in {

  options = {
    modules = {
      caddy = {
        enable = mkOption { type = types.bool; default = false; };
      };
    };
  };

  config = mkIf cfg.enable { 

  networking.firewall.allowedTCPPorts = [
    80 # Caddy
    443 # Caddy
    caddyMetricsPort
  ];

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
    configFile = ./Caddyfile;
  };

  systemd.services.caddy = {
    environment = {
      CLOUDFLARE_API_TOKEN =
        (builtins.readFile /etc/nixos/secrets/cloudflare-api-token);
    };

    serviceConfig = {
      # Required to use ports < 1024
      AmbientCapabilities = "cap_net_bind_service";
      CapabilityBoundingSet = "cap_net_bind_service";
    };
  };




  };


}
