{ config, pkgs, lib, ... }:

with lib;

let cfg = config.modules.remote-builder;
in {

  options.modules.remote-builder = { enable = mkEnableOption "Make this host compatible for aarch64-linux builds"; };

  config = mkIf cfg.enable {
    # For remote builds
    ## Caddy cannot be built in a sandbox because it retrieves external dependencies (i.e. cloudflare-dns module)
    nix.settings.sandbox = false;
    ## Don't garbage collect nix builds from deploy-rs
    ## Removing this will make failed deploys rebuild every time
    nix.settings.keep-outputs = true;
    nix.settings.keep-derivations = true;
    ## Emulate building for aarch64 (Raspberry Pi)
    boot.binfmt.emulatedSystems = [ "aarch64-linux" ];

  };
}
