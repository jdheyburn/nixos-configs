{ config, lib, pkgs, ... }:
{

  imports = [ ./hardware-configuration.nix ./networking.nix ];

  ###############################################################################
  ## General
  ###############################################################################

  system.stateVersion = "22.11";

  zramSwap.enable = true;

  networking.hostName = "charlie";
  networking.firewall.allowedTCPPorts = [ 22 3000 8096 ];
  #   networking.domain = "";

  services.openssh.enable = true;

  users.users.root.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIZdFaYhR7tRI5KyV3XG+jWb0CAT86QYdleQZCVBjUSY"
  ];

  ###############################################################################
  ## Modules
  ###############################################################################

  modules.caddy.enable = true;
  modules.dashy.enable = true;
  modules.monitoring.enable = true;
  modules.nfs-client.enable = true;

  environment.systemPackages = [
    pkgs.ffmpeg
    pkgs.restic
  ];

  environment.sessionVariables = {
    LD_LIBRARY_PATH = "${pkgs.stdenv.cc.cc.lib}/lib/";
  };

  programs.nix-ld.enable = true;

  services.jellyfin.enable = false;
  services.jellyfin.user = "jdheyburn";
  services.jellyfin.group = "users";

  modules.remote-builder.enable = true;

  # For tailscale exit nodes
  #boot.kernel.sysctl = {
  #  "net.ipv4.ip_forward" = 1;
  #  "net.ipv6.conf.all.forwarding" = 1;
  #};
}
