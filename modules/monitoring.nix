{ config, pkgs, lib, ... }:

{

  imports = [ ./promtail.nix ];

  networking.firewall.allowedTCPPorts = [ 9002 ];

  services.prometheus = {
    exporters = {
      node = {
        enable = true;
        enabledCollectors = [ "systemd" ];
        port = 9002;
      };
    };
  };
}
