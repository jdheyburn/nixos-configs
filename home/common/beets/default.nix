{ config, pkgs, lib, ... }:
let

  yamlFormat = pkgs.formats.yaml { };

  baseConfig = {
    plugins = [
      "edit"
      "discogs"
      "inline"
      "info"
      "badfiles"
      "missing"
      "embedart"
      "fetchart"
      #"bandcamp" 
      "lastgenre"
    ];

    directory = "/mnt/nfs/Backup/media/music";
    library = "/mnt/nfs/Backup/media/beets-db/beets-music.db";

    import = {
      move = false;
      copy = true;
      timid = true;
    };

    paths = {
      default = "$albumartist/$album%aunique{}/%if{$multidisc,CD$disc/}$track $artist - $title";
      comp = "Compilations/$album%aunique{}/%if{$multidisc,CD$disc/}$track $artist - $title";
      singleton = "Singles/$artist - $title";
    };

    item_fields.multidisc = "1 if disctotal > 1 and media == 'CD' else 0";

    original_date = true;

    threaded = true;

    fetchart = {
      cover_names = "cover";
      minwidth = 500;
      store_source = true;
    };

  };

in
{

  programs.beets.enable = true;

  beets.override { pluginOverrides = {
    alternatives = { enable = true; propagatedBuildInputs = [ beetsPackages.alternatives ]; };
  };
}

  xdg.configFile."beets/config-music.yaml".source =
yamlFormat.generate "beets-config" baseConfig;


}

