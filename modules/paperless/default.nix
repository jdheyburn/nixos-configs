{ catalog, config, pkgs, lib, ... }:

with lib;

let
  cfg = config.modules.paperless;
  port = catalog.services.paperless.port;
  documentsDir = "/mnt/nfs/documents/paperless";
in
{

  options.modules.paperless = {
    enable = mkEnableOption "Deploy paperless-ngx";
  };

  config = mkIf cfg.enable {

    services.caddy.virtualHosts."paperless.${catalog.domain.service}".extraConfig = ''
      tls {
        dns cloudflare {env.CLOUDFLARE_API_TOKEN}
      }
      reverse_proxy localhost:${toString port}
    '';

    age.secrets."paperless-password".file = ../../secrets/paperless-password.age;

    services.paperless = {
      enable = true;
      address = "0.0.0.0";
      port = port;
      mediaDir = "${documentsDir}/documents";
      consumptionDir = "${documentsDir}/consume";
      passwordFile = config.age.secrets."paperless-password".path;
      settings = {
        PAPERLESS_ADMIN_USER = "jdheyburn";
        PAPERLESS_URL = "https://paperless.${catalog.domain.service}";
        PAPERLESS_TIME_ZONE = "Europe/London";
      };
    };

    services.restic.backups.small-files = {
      paths = [ config.services.paperless.dataDir ];
    };
  };
}
