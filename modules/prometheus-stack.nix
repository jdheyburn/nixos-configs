{ config, pkgs, lib, ... }:

{
  services.grafana = {
    enable = true;
    domain = "grafana.svc.joannet.casa";
    port = 2342;
    addr = "127.0.0.1";
  };
}
