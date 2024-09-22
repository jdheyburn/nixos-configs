{ config, pkgs, lib, ... }:

with lib;

let cfg = config.modules.aria2;

in {

  options.modules.aria2 = { enable = mkEnableOption "enable aria2 with a web client for managing downloads"; };

  config = mkIf cfg.enable {

    services.caddy.virtualHosts."aria2.svc.joannet.casa" = {
      # Routing config inspired from below:
      # https://github.com/linuxserver/reverse-proxy-confs/blob/20c5dbdcff92442262ed8907385e477935ea9336/aria2-with-webui.subdomain.conf.sample
      extraConfig = ''
        tls {
          dns cloudflare {env.CLOUDFLARE_API_TOKEN}
        }
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
      ../../secrets/aria2-password.age;

    services.aria2 = {
      enable = true;
      rpcSecretFile = config.age.secrets."aria2-password".path;
    };
  };
}

