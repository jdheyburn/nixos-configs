{ config, pkgs, lib, ... }:


{
    services.adguard-exporter = {
        enable = true;
    };
}
