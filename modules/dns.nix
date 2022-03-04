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
    extraArgs = [ 
      # Router knows best, i.e. stop returning 127.0.0.1 for DNS calls for self
      "--no-etc-hosts"
       ];
    };

}
