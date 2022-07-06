{ config, pkgs, lib, ... }:

with lib;

let cfg = config.modules.plex;

in {

  options.modules.plex = {
    enable = mkEnableOption "Deploy plex";
  };

  config = mkIf cfg.enable {

    services.plex = {
      enable = true;
      openFirewall = true;
    };
  };
}
