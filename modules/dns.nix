{ config, pkgs, lib, ... }:

{ 

    networking.firewall = {
     allowedTCPPorts = [
       53 # DNS server
     ];
     allowedUDPPorts = [ 
       53 # DNS server
     ];
   };

  services.adguardhome = {
    enable = true;
  };

}
