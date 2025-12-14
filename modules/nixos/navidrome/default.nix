{ config, pkgs, lib, ... }:

with lib;

let cfg = config.modules.navidrome;

in {

  options.modules.navidrome = { enable = mkEnableOption "Deploy navidrome"; };

  config = mkIf cfg.enable {

    services.navidrome = {
      enable = true;
      settings = {
        Address = "0.0.0.0";
        MusicFolder = "/mnt/nfs/media/music";
      };
    };
  };
}

