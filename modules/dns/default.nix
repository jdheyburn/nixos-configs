{ catalog, config, pkgs, lib, ... }:

with lib;

let
  cfg = config.modules.dns;

  # Support both old and new method
  shouldDNS = service:
    (service ? "caddify" && service.caddify ? "enable" && service.caddify.enable) ||
    (service ? "dns" && service.dns ? "enable" && service.dns.enable);
    
  # Get services which are being served by caddy
  caddy_services = attrValues (filterAttrs
    (svc_name: svc_def: shouldDNS svc_def)
    catalog.services);

  getCaddyDestination = service:
    if service ? "caddify" && service.caddify ? "forwardTo" then
      service.caddify.forwardTo
    else
      service.host;

  # For each service create a list of rewrites
  rewrites = map
    (service: {
      domain = "${service.name}.svc.joannet.casa";
      answer = (getCaddyDestination service).ip.private;
    })
    caddy_services;
in
{

  options.modules.dns = { enable = mkEnableOption "Deploy AdGuardHome"; };

  config = mkIf cfg.enable {

    services.caddy.virtualHosts."adguard.svc.joannet.casa" = {
      # Routing config inspired from below:
      # https://github.com/linuxserver/reverse-proxy-confs/blob/20c5dbdcff92442262ed8907385e477935ea9336/aria2-with-webui.subdomain.conf.sample
      extraConfig = ''
        tls {
          dns cloudflare {env.CLOUDFLARE_API_TOKEN}
        }
        reverse_proxy localhost:${toString catalog.services.adguard.port}
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

    age.secrets."adguard-password".file = ../../secrets/adguard-password.age;

    services.adguardhome = {
      enable = true;
      extraArgs = [
        # Router knows best, i.e. stop returning 127.0.0.1 for DNS calls for self
        "--no-etc-hosts"
      ];
      settings = {
        bind_port = catalog.services.adguard.port;
        users = [{
          name = "admin";
          password =
            "$2a$10$4rSCa07722Xa9G8BXaBTP.HX973a4FiH7HXJ5Go0GIilPuR85KPLi";
        }];
        dns = {
          # bind_hosts = [ "0.0.0.0" ];
          bind_host = "0.0.0.0";
          edns_client_subnet.enabled = false;
          upstream_dns = [
            "https://dns10.quad9.net/dns-query"
            "[/joannet.casa//]192.168.1.1:53"
          ];
          bootstrap_dns =
            [ "9.9.9.10" "149.112.112.10" "2620:fe::10" "2620:fe::fe:10" ];
          rewrites = rewrites;
          resolve_clients = true;
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
