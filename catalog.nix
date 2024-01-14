# Catalog defines the systems & services on my network.
# Inspired from https://github.com/jhillyerd/homelab/blob/main/nixos/catalog.nix
{ nixos-hardware }: rec {

  nodesBase = {
    charlie = {
      ip.private = "128.140.63.95";
      system = "x86_64-linux";
      isNixOS = true;
    };

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
  nodes = builtins.listToAttrs (map
    (hostName: {
      name = hostName;
      value = (nodesBase."${hostName}" // { hostName = hostName; });
    })
    (builtins.attrNames nodesBase));

  servicesBase = {
    adguard = {
      host = nodes.dee;
      port = 3000;
      dashy.section = "networks";
      dashy.description = "DNS resolver";
      dashy.icon = "hl-adguardhome";
      dns.enable = true;
    };

    blackboxExporter = { port = 9115; };

    healthchecks = {
      host = nodes.dee;
      port = 8000;
      dashy.section = "monitoring";
      dashy.description = "Monitor status of cron jobs";
      dashy.icon = "hl-healthchecks";
      dns.enable = true;
    };

    home = {
      host = nodes.dennis;
      port = 4000;
      blackbox.name = "dashy";
      dns.enable = true;
    };

    huginn = {
      host = nodes.frank;
      port = 3000;
      caddify.forwardTo = nodes.dee;
      dashy.icon = "hl-huginn";
      dns.enable = false;
    };

    grafana = {
      host = nodes.dennis;
      port = 2342;
      dashy.section = "monitoring";
      dashy.description = "View logs and metrics";
      dashy.icon = "hl-grafana";
      dns.enable = true;
    };

    loki = {
      host = nodes.dennis;
      port = 3100;
      blackbox.path = "/ready";
      dns.enable = true;
    };

    nodeExporter = { port = 9002; };

    minio = {
      host = nodes.dee;
      port = 9100;
      consolePort = 9101;
      dns.enable = true;
    };

    "ui.minio" = {
      host = nodes.dee;
      port = services.minio.consolePort;
      dashy.section = "storage";
      dashy.description = "S3 compatible object storage";
      dashy.icon = "hl-minio";
      dns.enable = true;
    };

    portainer = {
      host = nodes.frank;
      port = 9000;
      caddify.forwardTo = nodes.dee;
      dashy.section = "virtualisation";
      dashy.description = "Frontend for containers";
      dashy.icon = "hl-portainer";
      dns.enable = false;
    };

    prometheus = {
      host = nodes.dennis;
      port = 9001;
      dashy.section = "monitoring";
      dashy.description = "Polls for metrics before captured by Thanos";
      dashy.icon = "hl-prometheus";
      dns.enable = false;
    };

    promtail = { port = 28183; };

    proxmox = {
      host = nodes.dee;
      port = 8006;
      dashy.section = "virtualisation";
      dashy.description = "Frontend for VMs";
      dashy.icon = "hl-proxmox";
      dns.enable = true;
    };

    plex = {
      host = nodes.dee;
      port = 32400;
      dashy.section = "media";
      dashy.description = "Watch TV and movies";
      dashy.icon = "hl-plex";
      dns.enable = true;
    };

    thanos-query = {
      host = nodes.dennis;
      port = 19192;
      grpcPort = 10902;
      dashy.section = "monitoring";
      dashy.description = "Long term storage for Prometheus metrics";
      dashy.icon = "hl-thanos";
      dns.enable = false;
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
      host = nodes.dennis;
      port = 8443;
      caddify.skip_tls_verify = true;
      dashy.section = "networks";
      dashy.description = "UniFi controller";
      dashy.icon = "hl-unifi-controller";
      dns.enable = true;
    };

    victoriametrics = {
      host = nodes.dennis;
      port = 8428;
      dashy.section = "monitoring";
      dashy.description = "Alternate poller of metrics in PromQL format";
      dashy.icon = "https://avatars.githubusercontent.com/u/43720803";
      dns.enable = true;
    };
  };

  # Enrich servicesBase by adding the key as the name - DRY
  services = builtins.listToAttrs (map
    (serviceName: {
      name = serviceName;
      value = (servicesBase."${serviceName}" // { name = serviceName; });
    })
    (builtins.attrNames servicesBase));
}
