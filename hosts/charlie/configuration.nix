{ config, lib, pkgs, ... }:
{

  imports = [ ./hardware-configuration.nix ./networking.nix ];

  ###############################################################################
  ## General
  ###############################################################################

  system.stateVersion = "22.11";

  zramSwap.enable = true;

  networking.hostName = "charlie";
  networking.firewall.allowedTCPPorts = [ 22 3000 ];
  #   networking.domain = "";

  services.openssh.enable = true;

  users.users.root.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIZdFaYhR7tRI5KyV3XG+jWb0CAT86QYdleQZCVBjUSY"
  ];

  ###############################################################################
  ## Modules
  ###############################################################################

  modules.monitoring.enable = true;

  environment.systemPackages = [
    pkgs.ffmpeg
  ];

  environment.sessionVariables = {
    LD_LIBRARY_PATH = "${pkgs.stdenv.cc.cc.lib}/lib/";
  };

  programs.nix-ld.enable = true;
}

