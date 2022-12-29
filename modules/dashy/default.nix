{ catalog, config, pkgs, lib, ... }:

with lib;

let
  version = "2.1.1";

  cfg = config.modules.dashy;

  # TODO extract to utils.toYAML
  format = pkgs.formats.yaml { };

  # Start to build the elements in sections, this is then used to discover in catalog.services
  sections = [
    {
      name = "Media";
      icon = "fas fa-play-circle";
    }
    {
      name = "Monitoring";
      icon = "fas fa-heartbeat";
    }
    {
      name = "Networks";
      icon = "fas fa-network-wired";
    }
    {
      name = "Storage";
      icon = "fas fa-database";
    }
    {
      name = "Virtualisation";
      icon = "fas fa-cloud";
    }
  ];

  # Determines if a given svc_def belongs to a dashy section
  isDashyService = section_name: svc_def:
    svc_def ? "dashy" && svc_def.dashy ? "section" && svc_def.dashy.section
    == section_name;

  # Build the items (services) for each section
  sectionServices = let
    createSectionItems = services:
      map (service: {
        title = service.name;
        description = service.dashy.description;
        url = "https://${service.name}.svc.joannet.casa";
        icon = service.dashy.icon;
      }) services;
    sectionItems = sectionName:
      createSectionItems (attrValues (filterAttrs
        (svc_name: svc_def: isDashyService (toLower sectionName) svc_def)
        catalog.services));
  in map (section: section // { items = sectionItems section.name; }) sections;

  dashyConfig = {
    pageInfo = {
      title = "Joannet";
      navLinks = [{
        title = "Dashy Documentation";
        path = "https://dashy.to/docs";
      }];
    };

    appConfig = {
      theme = "nord-frost";
      iconSize = "large";
      layout = "vertical";
      preventWriteToDisk = true;
      preventLocalSave = true;
      disableConfiguration = false;
      hideComponents = {
        hideSettings = true;
        hideFooter = true;
      };
    };

    sections = sectionServices;
  };

  # Creation of yaml file inspired from https://github.com/NixOS/nixpkgs/blob/master/nixos/modules/services/home-automation/home-assistant.nix
  # Couldn't get it to build with this
  # filteredConfig = lib.converge (lib.filterAttrsRecursive (_: v: ! elem v [ null ])) dashy-config or {};
  configFile =
    pkgs.runCommand "dashy-configuration.yaml" { preferLocalBuild = true; } ''
      cp ${format.generate "dashy-configuration.yaml" dashyConfig} $out
      sed -i -e "s/'\!\([a-z_]\+\) \(.*\)'/\!\1 \2/;s/^\!\!/\!/;" $out
    '';

in {
  options.modules.dashy = { enable = mkEnableOption "enable dashy"; };

  config = mkIf cfg.enable {

    virtualisation.oci-containers.containers = {
      dashy = {
        image = "lissy93/dashy:${version}";
        volumes = [ "${configFile}:/app/public/conf.yml" ];
        ports = [ "${toString catalog.services.home.port}:80" ];
      };
    };
  };
}

