{ catalog, config, pkgs, lib, myUtils, ... }:

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

    services.caddy.virtualHosts."paperless.${catalog.domain.service}".extraConfig =
      myUtils.caddy.mkServiceVHost { port = port; };

    age.secrets."paperless-password".file = myUtils.secrets.file "paperless-password";

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

