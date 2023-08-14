{ lib, ... }: {
  # This file was populated at runtime with the networking
  # details gathered from the active system.
  networking = {
    nameservers = [
      "8.8.8.8"
    ];
    defaultGateway = "172.31.1.1";
    defaultGateway6 = {
      address = "fe80::1";
      interface = "eth0";
    };
    dhcpcd.enable = false;
    usePredictableInterfaceNames = lib.mkForce false;
    interfaces = {
      eth0 = {
        ipv4.addresses = [
          { address = "128.140.63.95"; prefixLength = 32; }
        ];
        ipv6.addresses = [
          { address = "2a01:4f8:c17:6b5f::1"; prefixLength = 64; }
          { address = "fe80::9400:2ff:fe18:c7a6"; prefixLength = 64; }
        ];
        ipv4.routes = [{ address = "172.31.1.1"; prefixLength = 32; }];
        ipv6.routes = [{ address = "fe80::1"; prefixLength = 128; }];
      };

    };
  };
  services.udev.extraRules = ''
    ATTR{address}=="96:00:02:18:c7:a6", NAME="eth0"
    
  '';
}
