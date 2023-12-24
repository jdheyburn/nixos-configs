{ config, pkgs, lib, ... }:

with lib;

let cfg = config.modules.downloadManager;
in {

  options.modules.downloadManager = { enable = mkEnableOption "enable aria2 with a web client for managing downloads"; };

  config = mkIf cfg.enable {

    # TODO retrieve primary user programatically
    users.users.jdheyburn.extraGroups = [ "aria2" ];

    services.aria2 = {
      enable = true;
      openPorts = true;
      # TODO replace with secret from agenix
      rpcSecret = "foo";
      # TODO decide if all these are needed
      extraArguments = "--rpc-listen-all --rpc-allow-origin-all";
    };

    services.static-web-server = {
      enable = true;
      root = "${pkgs.ariang}/share/ariang";
      # TODO define port
      listen = "[::]:8585";
    };

    networking.firewall = {

      allowedTCPPorts = [
        8585
      ];
    };
  };
}

