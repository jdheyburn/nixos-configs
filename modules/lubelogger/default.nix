# Inspiration from https://github.com/firecat53/nixos/blob/52269c82a1195d70a4209d75ed8cf774234510ca/hosts/homeserver/services/lubelogger.nix#L7
{ catalog, config, pkgs, lib, ... }:

with lib;

let
  dataDir = "/var/lib/lubelogger";
  version = "1.4.1";
  cfg = config.modules.lubelogger;
in
{
  options = {
    modules.lubelogger = {
      enable = mkEnableOption "Lubelogger, a self-hosted, open-source, web-based vehicle maintenance and fuel milage tracker";
    };
  };

  config = mkIf cfg.enable {
    services.caddy.virtualHosts."lubelogger.svc.joannet.casa".extraConfig = ''
      tls {
        dns cloudflare {env.CLOUDFLARE_API_TOKEN}
        # Below required to get TLS to work on non-local hosts (i.e. charlie)
        resolvers 8.8.8.8
      }
      reverse_proxy localhost:${toString catalog.services.lubelogger.port}
    '';

    virtualisation.oci-containers.containers.lubelogger = {
      image = "ghcr.io/hargata/lubelogger:v${version}";
      volumes = [
        "${dataDir}/config:/App/config"
        "${dataDir}/data:/App/data"
        "${dataDir}/documents:/App/wwwroot/documents"
        "${dataDir}/images:/App/wwwroot/images"
        "${dataDir}/temp:/App/wwwroot/temp"
        "${dataDir}/log:/App/log"
        "${dataDir}/keys:/root/.aspnet/DataProtection-Key"
      ];
      ports = [ "${toString catalog.services.lubelogger.port}:8080" ];
      environment = {
        LC_ALL = "en_GB";
        LANG = "en_GB";
        UseDarkMode = "true";
        EnableAuth = "true";
        UserNameHash = "b53bdd407e178e9a00eb6d1b5cd5633564030ffb785904f7096109255f01631a";
        UserPasswordHash = "ab8cd8ab7d3930490ec8233671f4259ebadd84148e9226ac8081097be5c417d1";
      };
    };

    services.restic.backups.small-files = {
      paths = [
        dataDir
      ];
    };
  };
}
