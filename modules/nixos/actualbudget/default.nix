{ catalog, config, pkgs, lib, ... }:



with lib;

let

  cfg = config.modules.actualbudget;
  port = catalog.services.actual.port;

in
{
  # imports = [ ../../pkgs/actual.nix ];
  options.modules.actualbudget = {
    enable = mkEnableOption "enable actual budget";
  };

  config = mkIf cfg.enable {

    services.caddy.virtualHosts."actual.${catalog.domain.service}".extraConfig = ''
      tls {
        dns cloudflare {env.CLOUDFLARE_API_TOKEN}
      }
      reverse_proxy localhost:${toString port}
    '';

    # services.actual.enable = true;
    # services.actual.port = port;
  };
}
