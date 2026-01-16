{ config, pkgs, lib, ... }:

with lib;

let
  cfg = config.modules.beets;
  
  # Import beetcamp package for Bandcamp integration
  beetcamp = pkgs.callPackage ../../../pkgs/beetcamp.nix { };
  
  # Create a Python environment with beets and beetcamp for the PYTHONPATH
  beetsEnv = pkgs.python3.withPackages (ps: [
    ps.beets
    beetcamp
  ]);
  
  # Create a wrapped beets that uses the environment but only exposes the beet binary
  # This avoids conflicts with other Python environments in home.packages
  beetsWrapped = pkgs.runCommand "beets-wrapped" {
    nativeBuildInputs = [ pkgs.makeWrapper ];
  } ''
    mkdir -p $out/bin
    makeWrapper ${beetsEnv}/bin/beet $out/bin/beet
  '';

in {
  options.modules.beets = { 
    enable = mkEnableOption "Beets music library manager with beetcamp plugin"; 
  };

  config = mkIf cfg.enable {
    programs.beets = {
      enable = true;
      package = beetsWrapped;
    };

    home.file.".config/beets/config.yaml" = {
      source = ./config-music.yaml;
    };
  };
}
