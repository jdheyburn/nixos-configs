{ config, pkgs, lib, ... }:

with lib;

let
    unifiMinJavaHeapSize = 256;
in
{ 
    services.unifi = {
        enable = true;
        unifiPackage = pkgs.unifiStable;
        maximumJavaHeapSize = unifiMinJavaHeapSize;
        jrePackage = pkgs.jre8_headless;
        # TODO explore if this can be closed, if Caddy reverse proxies enough
        # Port 8443 does not need to be open because caddy proxies 443 -> 8443
        # But other ports may need to be open for unifi operations
        openFirewall = true;
    };
}
