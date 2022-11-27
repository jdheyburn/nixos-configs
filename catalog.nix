# Catalog defines the systems & services on my network.
# Inspired from https://github.com/jhillyerd/homelab/blob/main/nixos/catalog.nix
{ nixos-hardware }: rec {

  nodesBase = {
    dee = {
      ip.private = "192.168.1.10";
      ip.tailscale = "100.127.189.33";
      system = "aarch64-linux";
      isNixOS = true;
      nixosHardware = nixos-hardware.nixosModules.raspberry-pi-4;
    };

    dennis = {
      ip.private = "192.168.1.12";
      ip.tailscale = "100.127.102.123";
      system = "x86_64-linux";
      isNixOS = true;
    };

    frank = {
      ip.private = "192.168.1.11";
      ip.tailscale = "100.71.206.55";
      isNixOS = false;
    };

    paddys = {
      ip.private = "192.168.1.20";
      ip.tailscale = "100.107.150.109";
      isNixOS = false;
    };

    pve0 = {
      ip.private = "192.168.1.15";
      ip.tailscale = "100.80.112.68";
      isNixOS = false;
    };
  };

  # Enrich nodeBase by adding the key as the hostname - DRY
  nodes = builtins.listToAttrs (map (hostName: {
    name = hostName;
    value = (nodesBase."${hostName}" // { hostName = hostName; });
  }) (builtins.attrNames nodesBase));

  services = {
    adguard = {
      host = nodes.dee;
      port = 3000;
      caddify.enable = true;
      dashy.section = "networks";
      dashy.description = "DNS resolver";
      dashy.icon = "hl-adguardhome";
    };

    healthchecks = {
      host = nodes.dee;
      port = 8000;
      caddify.enable = true;
      dashy.section = "monitoring";
      dashy.description = "Monitor status of cron jobs";
      dashy.icon = "hl-healthchecks";
    };

    home = {
      host = nodes.dennis;
      port = 4000;
      blackbox.name = "dashy";
      caddify.enable = true;
    };

    huginn = {
      host = nodes.frank;
      port = 3000;
      caddify.enable = true;
      caddify.forwardTo = nodes.dee;
      dashy.icon = "hl-huginn";
    };

    grafana = {
      host = nodes.dennis;
      port = 2342;
      caddify.enable = true;
      dashy.section = "monitoring";
      dashy.description = "View logs and metrics";
      dashy.icon = "hl-grafana";
    };

    loki = {
      host = nodes.dennis;
      port = 3100;
      blackbox.path = "/ready";
      caddify.enable = true;
    };

    nodeExporter = { port = 9002; };

    minio = {
      host = nodes.dee;
      port = 9100;
      consolePort = 9101;
      caddify.enable = true;
    };

    "ui.minio" = {
      host = nodes.dee;
      port = services.minio.consolePort;
      caddify.enable = true;
      dashy.section = "storage";
      dashy.description = "S3 compatible object storage";
      dashy.icon = "hl-minio";
    };

    portainer = {
      host = nodes.frank;
      port = 9000;
      caddify.enable = true;
      caddify.forwardTo = nodes.dee;
      dashy.section = "virtualisation";
      dashy.description = "Frontend for containers";
      dashy.icon = "hl-portainer";
    };

    prometheus = {
      host = nodes.dennis;
      port = 9001;
      caddify.enable = true;
      dashy.section = "monitoring";
      dashy.description = "Polls for metrics before captured by Thanos";
      dashy.icon = "hl-prometheus";
    };

    promtail = { port = 28183; };

    proxmox = {
      host = nodes.pve0;
      port = 8006;
      caddify.enable = true;
      caddify.skip_tls_verify = true;
      caddify.forwardTo = nodes.dee;
      dashy.section = "virtualisation";
      dashy.description = "Frontend for VMs";
      dashy.icon = "hl-proxmox";
    };

    plex = {
      host = nodes.dee;
      port = 32400;
      caddify.enable = true;
      dashy.section = "media";
      dashy.description = "Watch TV and movies";
      dashy.icon = "hl-plex";
    };

    thanos-query = {
      host = nodes.dennis;
      port = 19192;
      grpcPort = 10902;
      caddify.enable = true;
      dashy.section = "monitoring";
      dashy.description = "Long term storage for Prometheus metrics";
      dashy.icon = "hl-thanos";
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
      host = nodes.dee;
      port = 8443;
      caddify.enable = true;
      caddify.skip_tls_verify = true;
      dashy.section = "networks";
      dashy.description = "UniFi controller";
      dashy.icon = "hl-unifi-controller";
    };

    victoriametrics = {
      host = nodes.dennis;
      port = 8428;
      caddify.enable = true;
      dashy.section = "monitoring";
      dashy.description = "Alternate poller of metrics in PromQL format";
      dashy.icon = "https://avatars.githubusercontent.com/u/43720803";
    };
  };
}
