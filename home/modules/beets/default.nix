{ config, pkgs, lib, ... }:

with lib;

let
  cfg = config.modules.beets;
  
  # Import beetcamp package for Bandcamp integration
  beetcamp = pkgs.callPackage ./beetcamp { };
  
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

  plugins = [
    "badfiles"
    "bandcamp"
    "discogs"
    "edit"
    "embedart"
    "fetchart"
    "inline"
    "info"
    "lastgenre"
    "missing"
    "musicbrainz"
  ];

in {
  options.modules.beets = { 
    enable = mkEnableOption "Beets music library manager with beetcamp plugin"; 
  };

  config = mkIf cfg.enable {
    programs.beets = {
      enable = true;
      package = beetsWrapped;
      settings = {
        plugins = concatStringsSep " " plugins;

        # Where to store the imported music files, and the db location for tracking
        directory = "/mnt/nfs/Backup/media/music";
        library = "/mnt/nfs/Backup/media/beets-db/beets-music.db";

        import = {
          move = false;
          copy = true;
          timid = true;
        };

        # How to store the files in directory
        # TODO want album included in the file name, but requires a migration to fix the paths in the db
        paths = {
          default = "$albumartist/$album%aunique{}/%if{$multidisc,CD$disc/}$track $artist - $title";
          comp = "Compilations/$album%aunique{}/%if{$multidisc,CD$disc/}$track $artist - $title";
          singleton = "Singles/$artist - $title";
        };

        # Custom fields we can refer to in paths
        # multidisc - if album has more than one CD then group by that CD within the album
        item_fields = {
          multidisc = "1 if disctotal > 1 and media == 'CD' else 0";
        };

        # Newer released media should use the original year it was released
        original_date = true;

        # Speedy
        threaded = true;

        fetchart = {
          cover_names = "cover";
          minwidth = 500;
          store_source = true;
        };
      };
    };
  };
}
