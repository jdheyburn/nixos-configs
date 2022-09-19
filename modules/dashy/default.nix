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

  # TODO make this dynamic from whatever is in the catalog
  dashy_services = {
    media = map (service_name:
      media_services."${service_name}" // {
        name = service_name;
      }) (attrNames media_services);
    monitoring = map (service_name:
      monitoring_services."${service_name}" // {
        name = service_name;
      }) (attrNames monitoring_services);
    networks = map (service_name:
      networks_services."${service_name}" // {
        name = service_name;
      }) (attrNames networks_services);
    storage = map (service_name:
      storage_services."${service_name}" // {
        name = service_name;
      }) (attrNames storage_services);
    virtualisation = map (service_name:
      virtualisation_services."${service_name}" // {
        name = service_name;
      }) (attrNames virtualisation_services);
  };

  # sections = map (section: ) (attrNames dashy_services);

  # dashy_services = filterAttrs (n: v: v ? "dashy" && v.dashy ? "section") catalog.services;

  # dashy_services_list = map
  #   (service_name: dashy_services."${service_name}" // { name = dashy_services; })
  #   (attrNames dashy_services);

  create_section_items = services:
    map (service: {
      title = service.name;
      description = service.dashy.description;
      url = "https://${service.name}.svc.joannet.casa";
      target = "newtab";
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

    appConfig.theme = "colorful";

    sections = [
      {
        name = "Media";
        icon = "fas fa-rocket";
        items = create_section_items dashy_services.media;
        # items =  [{
        #   title = "Dashy Live";
        #   description = "Development a project management links for Dashy";
        #   icon = "https://i.ibb.co/qWWpD0v/astro-dab-128.png";
        #   url = "https://live.dashy.to/";
        #   target = "newtab";
        # }];
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
        ports = [ "${catalog.dashy.port}:80" ];
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

