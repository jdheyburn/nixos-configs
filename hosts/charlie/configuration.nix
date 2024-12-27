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

  # TODO these secrets should be defined in the module
  age.secrets."restic-small-files-password".file =
    ../../secrets/restic-small-files-password.age;
  age.secrets."rclone.conf".file = ../../secrets/rclone.conf.age;

  modules.backup = {
    obsidian = {
      enable = true;
      rcloneConfigFile = config.age.secrets."rclone.conf".path;
    };
    small-files = {
      enable = true;
      rcloneConfigFile = config.age.secrets."rclone.conf".path;
      passwordFile = config.age.secrets."restic-small-files-password".path;
      healthcheck =
        "https://healthchecks.${config.catalog.domain.service}/ping/92e823bb-17ff-4d94-8a41-fcad88fb3b21";
    };
  };
  modules.caddy.enable = true;
  modules.dashy.enable = true;
  modules.lubelogger.enable = true;
  modules.monitoring.enable = true;
  modules.nfs-client.enable = true;
  modules.prometheusStack = {
    enable = true;
    blackbox.enable = true;
    grafana.enable = true;
    loki.enable = true;
    victoriametrics.enable = true;
  };
  modules.remote-builder.enable = true;

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

  # For tailscale exit nodes
  #boot.kernel.sysctl = {
  #  "net.ipv4.ip_forward" = 1;
  #  "net.ipv6.conf.all.forwarding" = 1;
  #};
}
