{ catalog, config, flake-self, pkgs, lib, ... }:

with lib;

let
  cfg = config.modules.dns;

  isEnabled = moduleName: hostName:
    let
      parts = splitString "." moduleName;
      module = builtins.foldl' (acc: part: builtins.getAttr part acc) flake-self.nixosConfigurations."${hostName}".config.modules parts;
    in
    module.enable;

  shouldDNS = service:
    # Only create DNS entries if the host that catalog.service says its running on has it enabled
    # service.modules is a list of strings that contain paths to check for enabling, see catalog.nix
    service ? "modules" && (all (x: x) (map (moduleName: isEnabled moduleName service.host.hostName) service.modules));

  # Get services which are being served by caddy
  caddy_services = attrValues (filterAttrs
    (svc_name: svc_def: shouldDNS svc_def)
    catalog.services);

  # For each service create a list of rewrites
  service_rewrites = map
    (service: {
      domain = "${service.name}.${catalog.domain.service}";
      answer = if service.host.ip ? "private" then service.host.ip.private else service.host.ip.tailscale;
    })
    caddy_services;
  # Add rewrites for any node that has a domain
  # Implies it is external so hook it up with joannet.casa
  host_rewrites = map
    (node: {
      domain = "${node.hostName}.joannet.casa";
      answer = node.ip.tailscale;
    })
    (attrValues (filterAttrs (node_name: node_def: node_def ? "domain") catalog.nodes));

  rewrites = service_rewrites ++ host_rewrites;

  port = catalog.services.adguard.port;
in
{

  options.modules.dns = { enable = mkEnableOption "Deploy AdGuardHome"; };

  config = mkIf cfg.enable {

    services.caddy.virtualHosts."adguard.${catalog.domain.service}" = {
      # Routing config inspired from below:
      # https://github.com/linuxserver/reverse-proxy-confs/blob/20c5dbdcff92442262ed8907385e477935ea9336/aria2-with-webui.subdomain.conf.sample
      extraConfig = ''
        tls {
          dns cloudflare {env.CLOUDFLARE_API_TOKEN}
        }
        reverse_proxy localhost:${toString port}
      '';
    };

    users.users.jdheyburn.extraGroups = [ "adguardhome" ];

    networking.firewall = {
      allowedTCPPorts = [
        53 # DNS server
        #    config.services.adguard-exporter.exporterPort
      ];
      allowedUDPPorts = [
        53 # DNS server
      ];
    };

    age.secrets."adguard-password".file = ../../../secrets/adguard-password.age;

    services.adguardhome = {
      enable = true;
      extraArgs = [
        # Router knows best, i.e. stop returning 127.0.0.1 for DNS calls for self
        "--no-etc-hosts"
      ];
      mutableSettings = false;
      settings = {
        port = port;
        users = [{
          name = "admin";
          password =
            "$2a$10$4rSCa07722Xa9G8BXaBTP.HX973a4FiH7HXJ5Go0GIilPuR85KPLi";
        }];
        dns = {
          edns_client_subnet.enabled = false;
          upstream_dns = [
            "https://dns10.quad9.net/dns-query"
            "[/joannet.casa//]192.168.1.1:53"
          ];
          bootstrap_dns =
            [ "9.9.9.10" "149.112.112.10" "2620:fe::10" "2620:fe::fe:10" ];
          resolve_clients = true;
        };

        filtering = {
          rewrites = rewrites;
        };

        statistics.interval = "24h";

        user_rules = [
          "@@||skyads.ott.skymedia.co.uk^$client='192.168.1.112'"
          #          "||www.bbc.com^$client='192.168.1.25'"
          #          "||www.bbc.co.uk^$client='192.168.1.25'"
          "@@||skyads.ott.skymedia.co.uk^$important" # permits skyads, undoes the block in line 1
          "@@||stats.grafana.org^$important" # permits grafana stats
        ];
      };
    };

    services.restic.backups.small-files = {
      paths = [
        "/var/lib/AdGuardHome/"
        "/var/lib/private/AdGuardHome"
      ];
    };

    # TODO change to prometheus when it is added there
    #services.adguard-exporter = {
    #  enable = false;
    #  protocol = "http";
    #  username = "admin";
    #  passwordFile = "/etc/nixos/secrets/adguard-password";
    #  port = config.services.adguardhome.port;
    #};

  };
}
