{ config, lib, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
  ];

  ###############################################################################
  ## General
  ###############################################################################

  # TODO hostname should be inferred from where we're deploying to
  networking.hostName = "mac";
  #   networking.hostId = "";

  system.stateVersion = "23.11";


  boot.loader.grub.enable = true;
  boot.loader.grub.device = "/dev/sda";

  # For remote builds
  ## Caddy cannot be built in a sandbox because it retrieves external dependencies (i.e. cloudflare-dns module)
  nix.settings.sandbox = false;
  ## Don't garbage collect nix builds from deploy-rs
  ## Removing this will make failed deploys rebuild every time
  nix.settings.keep-outputs = true;
  nix.settings.keep-derivations = true;
  ## Emulate building for aarch64 (Raspberry Pi)
  boot.binfmt.emulatedSystems = [ "aarch64-linux" ];
}

