{ config, pkgs, lib, ... }:

with lib;

let cfg = config.modules.plex;

in {

  options.modules.plex = {
    enable = mkOption {
      type = types.bool;
      default = false;
    };
  };

  config = mkIf cfg.enable {

    services.plex = {
      enable = true;
      openFirewall = true;
    };
  };
}
