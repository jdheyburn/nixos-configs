{ config, system, inputs, ... }:
let
  spicePkgs = inputs.spicetify-nix.legacyPackages.${system};
  # The stable darwin spotify fetches its dmg from a Wayback Machine snapshot
  # that has since disappeared; the archive redirects to a neighbouring
  # snapshot and the hash no longer matches. Unstable pins a snapshot that
  # still exists. spicetify-cli comes along so it supports that Spotify.
  pkgsUnstable = import inputs.nixpkgs-unstable {
    inherit system;
    config.allowUnfree = true;
  };
in
{
  imports = [ inputs.spicetify-nix.homeManagerModules.spicetify ];

  # Spotify patched by spicetify, installed into home.packages. This replaces
  # the Homebrew cask; don't also install pkgs.spotify.
  # Options: https://gerg-l.github.io/spicetify-nix/options.html
  programs.spicetify = {
    enable = true;
    spotifyPackage = pkgsUnstable.spotify;
    spicetifyPackage = pkgsUnstable.spicetify-cli;
    # catppuccin/nix has no spicetify integration, so reuse its flavor
    # (home/common). The theme's color schemes are named after the flavors.
    theme = spicePkgs.themes.catppuccin;
    colorScheme = config.catppuccin.flavor;
    enabledExtensions = with spicePkgs.extensions; [
      hidePodcasts
      shuffle
    ];
  };
}
