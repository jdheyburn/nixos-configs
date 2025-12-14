{ catalog, config, pkgs, lib, utils, ... }:

with lib;

let cfg = config.modules.aria2;

in {

  options.modules.aria2 = { enable = mkEnableOption "enable aria2 with a web client for managing downloads"; };

  config = mkIf cfg.enable {

    services.caddy.virtualHosts."aria2.${catalog.domain.service}" = {
      # Routing config inspired from below:
      # https://github.com/linuxserver/reverse-proxy-confs/blob/20c5dbdcff92442262ed8907385e477935ea9336/aria2-with-webui.subdomain.conf.sample
      extraConfig = ''
        ${utils.caddy.cloudflareTLS false}
        reverse_proxy /jsonrpc localhost:${toString config.services.aria2.settings.rpc-listen-port}
        file_server {
          root ${pkgs.ariang}/share/ariang
        }
      '';
    };

    # TODO retrieve primary user programatically
    # Needed so that I can modify downloaded files
    users.users.jdheyburn.extraGroups = [ "aria2" ];

    age.secrets."aria2-password".file =
      utils.secrets.file "aria2-password";

    services.aria2 = {
      enable = true;
      rpcSecretFile = config.age.secrets."aria2-password".path;
    };
  };
}

