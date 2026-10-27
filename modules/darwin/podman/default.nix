{ config, pkgs, lib, ... }:

with lib;

let
  cfg = config.modules.podman;
  podman-mac-net-connect = pkgs.callPackage ./package.nix { };
in
{
  options.modules.podman = {
    enable = mkEnableOption "podman, with a tunnel so macOS can reach container IPs";
  };

  config = mkIf cfg.enable {

    environment.systemPackages = [
      pkgs.podman
      podman-mac-net-connect
    ];

    # Runs as root to create the utun interface and routes. It shells out to
    # `podman system connection list`, which reads the primary user's podman
    # config, so it needs podman on PATH and that user's HOME.
    launchd.daemons.podman-mac-net-connect = {
      command = getExe podman-mac-net-connect;
      environment = {
        HOME = "/Users/${config.system.primaryUser}";
        PATH = "${pkgs.podman}/bin:/usr/bin:/bin:/usr/sbin:/sbin";
      };
      serviceConfig = {
        RunAtLoad = true;
        KeepAlive = true;
        StandardOutPath = "/var/log/podman-mac-net-connect.log";
        StandardErrorPath = "/var/log/podman-mac-net-connect.log";
      };
    };
  };
}
