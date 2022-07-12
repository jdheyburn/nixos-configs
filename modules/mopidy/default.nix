{ config, pkgs, lib, ... }:

with lib;

let cfg = config.modules.mopidy;

in {

  options.modules.mopidy = { enable = mkEnableOption "Deploy mopidy"; };

  config = mkIf cfg.enable {

    networking.firewall.allowedTCPPorts = [ 6680 ];

    services.mopidy = {
      enable = true;
      extensionPackages = [ pkgs.mopidy-mopify ];

      configuration = ''
        [http]
        hostname = 0.0.0.0

        [mopify]
        enabled = false # can't get it to load, complains about mem module missing
        debug = false
      '';
    };
  };
}

