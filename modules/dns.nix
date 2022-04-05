{ config, pkgs, lib, ... }:

{

  networking.firewall = {
    allowedTCPPorts = [
      53 # DNS server
      #    config.services.adguard-exporter.exporterPort
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

  # TODO change to prometheus when it is added there
  #services.adguard-exporter = {
  #  enable = false;
  #  protocol = "http";
  #  username = "admin";
  #  passwordFile = "/etc/nixos/secrets/adguard-password";
  #  port = config.services.adguardhome.port;
  #};
}
