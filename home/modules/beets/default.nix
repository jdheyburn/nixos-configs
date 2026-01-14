{ config, pkgs, lib, ... }:

with lib;

let
  cfg = config.modules.beets;
  
  # Import beetcamp package for Bandcamp integration
  beetcamp = pkgs.callPackage ../../../pkgs/beetcamp.nix { };
  
  # Create beets with beetcamp plugin using a Python environment
  beetsWithBeetcamp = pkgs.python3.withPackages (ps: [
    ps.beets
    beetcamp
  ]);

in {
  options.modules.beets = { 
    enable = mkEnableOption "Beets music library manager with beetcamp plugin"; 
  };

  config = mkIf cfg.enable {
    # Use home-manager's programs.beets with our custom package
    programs.beets = {
      enable = true;
      package = beetsWithBeetcamp;
    };

    # Install additional config files for multi-library support
    # Use with: beet -c ~/.config/beets/config-music.yaml <command>
    home.file.".config/beets/config-music.yaml" = {
      source = ./config-music.yaml;
    };

    home.file.".config/beets/config-vinyl.yaml" = {
      source = ./config-vinyl.yaml;
    };

    home.file.".config/beets/config-lossless.yaml" = {
      source = ./config-lossless.yaml;
    };
  };
}

