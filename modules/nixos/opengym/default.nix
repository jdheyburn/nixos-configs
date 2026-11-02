# https://github.com/DuarteSantos8/openGym/blob/main/docs/NIX.md
{ catalog, config, lib, myUtils, opengym, ... }:

with lib;

let
  cfg = config.modules.opengym;
  service = catalog.services.gym;
  # Passkeys are bound to this hostname. Changing it invalidates every
  # registered passkey.
  hostName = "${service.name}.${catalog.domain.service}";
in
{
  imports = [ opengym.nixosModules.default ];

  options.modules.opengym = {
    enable = mkEnableOption "openGym, a self-hosted gym and body-weight tracker";
  };

  config = mkIf cfg.enable {
    services.opengym = {
      enable = true;
      apiPort = service.port;
      rpId = hostName;
      origin = "https://${hostName}";
    };

    # The API keeps its /api prefix, so /api is handled before the SPA
    # catch-all, which serves the frontend and exercise media from the store.
    services.caddy.virtualHosts.${hostName}.extraConfig = ''
      ${myUtils.caddy.cloudflareTLS true}
      encode zstd gzip

      handle /api/* {
        reverse_proxy localhost:${toString service.port}
      }
      handle {
        root * ${config.services.opengym.web.root}
        try_files {path} /index.html
        file_server
      }
    '';

    services.restic.backups.small-files.paths = [
      config.services.opengym.dataDir
    ];
  };
}
