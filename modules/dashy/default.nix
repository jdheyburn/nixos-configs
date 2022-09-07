{ catalog, config, pkgs, lib, ... }:

with lib;

let cfg = config.modules.dashy;
in {
  options.modules.dashy = {
    enable = mkEnableOption "enable dashy";
  };

  # TODO generate dashy config from catalog
  dashy-config = mkIf cfg.enable {

  };

  config = mkIf cfg.enable {

    virtualisation.oci-containers.containers = {
     dashy = {
       image = "lissy93/dashy:2.1.1";
       volumes = [ ":/app/public/conf.yml" ];
       ports = ["4000:80"];
    #    volumes = [
    #      "/root/hackagecompare/packageStatistics.json:/root/hackagecompare/packageStatistics.json"
    #    ];
    #    cmd = [
    #      "--name my-dashboard"
    #    ];
     };
   };
  };
}

