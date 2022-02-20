{ config, pkgs, lib, ... }:

{

  ## TODO might not be needed to open for localhost polling on dennis
  networking.firewall.allowedTCPPorts = [ 9092 ];

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
