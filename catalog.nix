# Catalog defines the systems & services on my network.
# Inspired from https://github.com/jhillyerd/homelab/blob/main/nixos/catalog.nix
{ system }: rec {

  nodes = {
    dee = {
      ip.private = "192.168.1.10";
      ip.tailscale = "100.127.189.33";
      system = system.aarch64-linux;
    };

    dennis = {
      ip.private = "192.168.1.12";
      ip.tailscale = "100.127.102.123";
      system = system.x86_64-linux;
    };

  };

  services = {
    # TODO reverse proxy on each host, it builds the rewrites depending on what services
    # are enabled on it. Then AdGuardHome config DNS rewrites are created based off what is
    # defined here.
    # i.e. for below, a Caddy instance is created on dennis that reverse proxies 
    # grafana.svc.joannet.casa to 127.0.0.1:2342
    # then AGH creates a DNS rewrite for grafana.svc.joannet.casa -> 192.168.1.12
    grafana = {
      host = "dennis";
      port = 2342;
      caddify.enable = true;
    };

    loki = {
      host = "dennis";
      port = 3100;
      caddify.enable = true;
    };

    nodeExporter = {
      host = "all";
      port = 9002;
    };

    prometheus = {
      host = "dennis";
      port = 9001;
      caddify.enable = true;
    };

    plex = {
      host = "dee";
      port = 32400;
      caddify.enable = true;
    };
    unifi = {
      host = "dee";
      port = 8443;
      caddify.enable = true;
      caddify.skip_tls_verify = true;
    };

  };

}

