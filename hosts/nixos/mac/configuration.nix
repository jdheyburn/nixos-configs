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


  ###############################################################################
  ## Modules
  ###############################################################################

  modules.monitoring.enable = true;
  modules.remote-builder.enable = true;

}

