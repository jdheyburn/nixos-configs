{ config, lib, pkgs, inputs ? null, ... }:

with lib;

let
  cfg = config.modules.musiclib;
in
{
  options.modules.musiclib = {
    enable = mkEnableOption "musiclib, the vinyl rip to beets import pipeline";
  };

  config = mkIf cfg.enable {
    # Built from the scratch flake rather than callPackage'd here, so bumping
    # the tool is `nix flake update scratch` rather than editing a rev and a hash.
    #
    # `inputs` defaults to null because homeConfigurations (the standalone
    # build) has no extraSpecialArgs, and module arguments are resolved for
    # every imported module whether or not it is enabled. mkIf keeps this
    # expression unevaluated there, so null is never dereferenced.
    home.packages = [
      inputs.scratch.packages.${pkgs.stdenv.hostPlatform.system}.musiclib
    ];
  };
}
