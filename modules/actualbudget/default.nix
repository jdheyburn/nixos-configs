{ catalog, config, pkgs, lib, ... }:



with lib;

let

  cfg = config.modules.actualbudget;

in
{
  imports = [ ../../pkgs/actual.nix ];
  options.modules.actualbudget = { enable = mkEnableOption "enable actual budget"; };

  config = mkIf cfg.enable {

    services.caddy.virtualHosts."actual.svc.joannet.casa".extraConfig = ''
      tls {
        dns cloudflare {env.CLOUDFLARE_API_TOKEN}
      }
      reverse_proxy localhost:${toString catalog.services.actual.port}
    '';

    services.actual.enable = true;
    services.actual.port = catalog.services.actual.port;

  };
}
