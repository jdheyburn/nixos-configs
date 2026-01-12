{ catalog, config, pkgs, lib, myUtils, ... }:



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

    services.caddy.virtualHosts."actual.${catalog.domain.service}".extraConfig =
      myUtils.caddy.mkServiceVHost {
        port = port;
        resolvers = false;
      };

    # services.actual.enable = true;
    # services.actual.port = port;
  };
}
