{ catalog, config, pkgs, lib, ... }:

with lib;

let
  version = "2.1.1";

  cfg = config.modules.dashy;
  format = pkgs.formats.yaml { };

  get_dashy_services = section:
    filterAttrs
    (n: v: v ? "dashy" && v.dashy ? "section" && v.dashy.section == section)
    catalog.services;

  media_services = get_dashy_services "media";
  monitoring_services = get_dashy_services "monitoring";
  networks_services = get_dashy_services "networks";
  storage_services = get_dashy_services "storage";
  virtualisation_services = get_dashy_services "virtualisation";

  services_as_list = services:
    map (service_name: services."${service_name}" // { name = service_name; })
    (attrNames services);

  # TODO make this dynamic from whatever is in the catalog
  dashy_services = {
    media = services_as_list media_services;
    monitoring = services_as_list monitoring_services;
    networks = services_as_list networks_services;
    storage = services_as_list storage_services;
    virtualisation = services_as_list virtualisation_services;
  };

  create_section_items = services:
    map (service: {
      title = service.name;
      description = service.dashy.description;
      url = "https://${service.name}.svc.joannet.casa";
      icon = service.dashy.icon;
    }) services;

  # TODO should generate config
  dashy-config = {
    pageInfo = {
      title = "Dashy";
      description = "Welcome to your new dashboard!";
      navLinks = [
        {
          title = "GitHub";
          path = "https://github.com/Lissy93/dashy";
        }
        {
          title = "Documentation";
          path = "https://dashy.to/docs";
        }
      ];
    };

    appConfig = {
      theme = "nord-frost";
      iconSize = "large";
      layout = "vertical";
      preventWriteToDisk = true;
      preventLocalSave = true;
      disableConfiguration = true;
    };

    sections = [
      {
        name = "Media";
        icon = "mdi-multimedia";
        items = create_section_items dashy_services.media;
      }
      {
        name = "Monitoring";
        icon = "fas fa-rocket";
        items = create_section_items dashy_services.monitoring;
      }
      {
        name = "Networks";
        icon = "fas fa-rocket";
        items = create_section_items dashy_services.networks;
      }
      {
        name = "Storage";
        icon = "fas fa-rocket";
        items = create_section_items dashy_services.storage;
      }
      {
        name = "Virtualisation";
        icon = "fas fa-rocket";
        items = create_section_items dashy_services.virtualisation;
      }
    ];
  };

  # Creation of yaml file inspired from https://github.com/NixOS/nixpkgs/blob/master/nixos/modules/services/home-automation/home-assistant.nix
  # Couldn't get it to build with this
  # filteredConfig = lib.converge (lib.filterAttrsRecursive (_: v: ! elem v [ null ])) dashy-config or {};
  configFile =
    pkgs.runCommand "dashy-configuration.yaml" { preferLocalBuild = true; } ''
      cp ${format.generate "dashy-configuration.yaml" dashy-config} $out
      sed -i -e "s/'\!\([a-z_]\+\) \(.*\)'/\!\1 \2/;s/^\!\!/\!/;" $out
    '';

in {
  options.modules.dashy = { enable = mkEnableOption "enable dashy"; };

  # TODO generate dashy config from catalog

  config = mkIf cfg.enable {

    virtualisation.oci-containers.containers = {
      dashy = {
        image = "lissy93/dashy:${version}";
        volumes = [ "${configFile}:/app/public/conf.yml" ];
        ports = [ "${toString catalog.services.home.port}:80" ];
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

