{ catalog, config, pkgs, lib, ... }:

with lib;

let

  cfg = config.modules.caddy;

  caddyMetricsPort = 2019;
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
      package = pkgs.caddy.withPlugins {
        plugins = [ "github.com/caddy-dns/cloudflare@v0.2.1" ];
        #hash = "sha256-2D7dnG50CwtCho+U+iHmSj2w14zllQXPjmTHr6lJZ/A=";
       hash = "sha256-Dvifm7rRwFfgXfcYvXcPDNlMaoxKd5h4mHEK6kJ+T4A=";
      };
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
