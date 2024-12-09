{ catalog, config, pkgs, lib, ... }:

with lib;

let
  version = "v1.7.7-ls40";
  dataDir = "/var/lib/obsidian";

  cfg = config.modules.dashy;

in
{
  options.modules.obsidian = { enable = mkEnableOption "enable obsidian"; };

  config = mkIf cfg.enable {
    services.caddy.virtualHosts."obsidian.svc.joannet.casa".extraConfig = ''
      tls {
        dns cloudflare {env.CLOUDFLARE_API_TOKEN}
        # Below required to get TLS to work on non-local hosts (i.e. charlie)
        resolvers 8.8.8.8
      }
      reverse_proxy localhost:${toString catalog.services.obsidian.port}
    '';

    virtualisation.oci-containers.containers.obsidian = {
      image = "lscr.io/linuxserver/obsidian:${version}";
      volumes = [ "${dataDir}/config:/config" ];
      ports = [ "${toString catalog.services.obsidian.port}:${toString catalog.services.obsidian.port}" ];
      environment = {
        CUSTOM_PORT = toString catalog.services.obsidian.port;
        PUID = "1000";
        PGUID = "100";
        TZ = "Europe/London";
      };
      extraOptions = [
        "--network=bridge"
      ];
    };
  };
}
