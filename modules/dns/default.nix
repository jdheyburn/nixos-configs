{ catalog, config, pkgs, lib, ... }:

with lib;

let
  cfg = config.modules.dns;

  # Get services which are being served by caddy
  caddy_services = filterAttrs
    (n: v: v ? "caddify" && v.caddify ? "enable" && v.caddify.enable)
    catalog.services;

  # Convert it to a list
  caddy_services_list = map
    (service_name: caddy_services."${service_name}" // { name = service_name; })
    (attrNames caddy_services);

  get_forward_to_node = service:
    if service.caddify ? "forwardTo" then
      catalog.nodes."${service.caddify.forwardTo}"
    else
      catalog.nodes."${service.host}";

  # Add the IP address for the host the service is on
  caddy_host_services =
    map (service: service // { ip = (get_forward_to_node service).ip.private; })
    caddy_services_list;

  # For each service create a list of rewrites
  rewrites = map (service: {
    domain = "${service.name}.svc.joannet.casa";
    answer = service.ip;
  }) caddy_host_services;

in {

  options.modules.dns = { enable = mkEnableOption "Deploy AdGuardHome"; };

  config = mkIf cfg.enable {

    networking.firewall = {
      allowedTCPPorts = [
        53 # DNS server
        #    config.services.adguard-exporter.exporterPort
      ];
      allowedUDPPorts = [
        53 # DNS server
      ];
    };

    age.secrets."adguard-password".file = ../../secrets/adguard-password.age;

    services.adguardhome = {
      enable = true;
      extraArgs = [
        # Router knows best, i.e. stop returning 127.0.0.1 for DNS calls for self
        "--no-etc-hosts"
      ];
      settings = {
        users = [{
          name = "admin";
          password =
            "$2a$10$4rSCa07722Xa9G8BXaBTP.HX973a4FiH7HXJ5Go0GIilPuR85KPLi";
        }];
        dns = {
          # bind_hosts = [ "0.0.0.0" ];
          bind_host = "0.0.0.0";
          upstream_dns = [
            "https://dns10.quad9.net/dns-query"
            "[/joannet.casa//]192.168.1.1:53"
          ];
          bootstrap_dns = "9.9.9.10";
          # for some reason this gets generated in yaml as bootstrap_dns: '[9.9.9.10 149.112.112.10 ...]'
          # Is a bug with NixOS and due to be released
          # https://github.com/NixOS/nixpkgs/pull/176701
          #bootstrap_dns = [
          #  "9.9.9.10"
          #  "149.112.112.10"
          #  "2620:fe::10"
          #  "2620:fe::fe:10"
          #];
          rewrites = rewrites;
          resolve_clients = true;
        };

        user_rules = [
          "@@||skyads.ott.skymedia.co.uk^$client='192.168.1.112'"
          #          "||www.bbc.com^$client='192.168.1.25'"
          #          "||www.bbc.co.uk^$client='192.168.1.25'"
          "@@||skyads.ott.skymedia.co.uk^$important" # permits skyads, undoes the block in line 1
          "@@||stats.grafana.org^$important" # permits grafana stats
        ];
      };
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
