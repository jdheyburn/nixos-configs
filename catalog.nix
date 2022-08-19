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

    frank = {
      ip.private = "192.168.1.11";
      ip.tailscale = "100.71.206.55";
    };

    proxmox = {
      ip.private = "192.168.1.15";
      ip.tailscale = "100.80.112.68";
    };
  };

  services = {
    adguard = {
      host = "dee";
      port = 3000;
      caddify.enable = true;
    };

    home = {
      host = "frank";
      port = 49154;
      caddify.enable = true;
      caddify.forwardTo = "dee";
    };

    huginn = {
      host = "frank";
      port = 3000;
      caddify.enable = true;
      caddify.forwardTo = "dee";
    };

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

    nodeExporter = { port = 9002; };

    minio = {
      host = "dee";
      port = 9100;
      consolePort = 9101;
      caddify.enable = true;
    };

    "ui.minio" = {
      host = "dee";
      port = services.minio.consolePort;
      caddify.enable = true;
    };

    portainer = {
      host = "frank";
      port = 9000;
      caddify.enable = true;
      caddify.forwardTo = "dee";
    };

    prometheus = {
      host = "dennis";
      port = 9001;
      caddify.enable = true;
    };

    proxmox = {
      host = "proxmox";
      port = 8006;
      caddify.enable = true;
      caddify.skip_tls_verify = true;
      caddify.forwardTo = "dee";
    };

    plex = {
      host = "dee";
      port = 32400;
      caddify.enable = true;
    };

    thanos-query = {
      host = "dennis";
      port = 19192;
      grpcPort = 10902;
      caddify.enable = true;
    };

    thanos-sidecar = {
      port = 19191;
      grpcPort = 10901;
    };

    thanos-store = {
      port = 19193;
      grpcPort = 10903;
    };

    unifi = {
      host = "dee";
      port = 8443;
      caddify.enable = true;
      caddify.skip_tls_verify = true;
    };

  };

}

