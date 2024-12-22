# Catalog defines the systems & services on my network.
# Inspired from https://github.com/jhillyerd/homelab/blob/main/nixos/catalog.nix
{ nixos-hardware }: rec {

  tailscale.domain = "bishop-beardie.ts.net";

  nodesBase = {
    charlie = {
      ip.tailscale = "100.74.217.71";
      system = "x86_64-linux";
      shouldScrape = true;
      users = [ users.jdheyburn ];
    };

    dee = {
      ip.private = "192.168.1.10";
      ip.tailscale = "100.127.189.33";
      system = "aarch64-linux";
      nixosHardware = nixos-hardware.nixosModules.raspberry-pi-4;
      shouldScrape = true;
      users = [ users.jdheyburn ];
    };

    dennis = {
      ip.private = "192.168.1.12";
      ip.tailscale = "100.127.102.123";
      system = "x86_64-linux";
      shouldScrape = false;
      users = [ users.jdheyburn ];
    };

    frank = {
      ip.private = "192.168.1.11";
      ip.tailscale = "100.71.206.55";
      shouldScrape = false;
    };

    mac = {
      ip.tailscale = "100.125.40.20";
      system = "x86_64-linux";
      shouldScrape = true;
      users = [ users.jdheyburn ];
    };

    macbook = {
      ip.private = "192.168.1.26";
      # Could either be Apple Silicon or Intel arch
      system = "aarch64-darwin";
      shouldScrape = false;
      users = [ users."joseph.heyburn" ];
    };

    paddys = {
      ip.private = "192.168.1.20";
      ip.tailscale = "100.107.150.109";
      shouldScrape = true;
    };

    pve0 = {
      ip.private = "192.168.1.15";
      ip.tailscale = "100.80.112.68";
      shouldScrape = false;
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
    actual = {
      host = nodes.dee;
      port = 5006;
      modules = [ "actualbudget" ];
    };

    adguard = {
      host = nodes.dee;
      port = 3000;
      dashy.section = "networks";
      dashy.description = "DNS resolver";
      dashy.icon = "hl-adguardhome";
      modules = [ "dns" ];
    };

    aria2 = {
      host = nodes.dee;
      modules = [ "aria2" ];
    };

    blackboxExporter = { port = 9115; };

    healthchecks = {
      host = nodes.dee;
      port = 8000;
      dashy.section = "monitoring";
      dashy.description = "Monitor status of cron jobs";
      dashy.icon = "hl-healthchecks";
      modules = [ "healthchecks" ];
    };

    home = {
      host = nodes.charlie;
      port = 4000;
      blackbox.name = "dashy";
      modules = [ "dashy" ];
    };

    huginn = {
      host = nodes.frank;
      port = 3000;
      dashy.icon = "hl-huginn";
    };

    grafana = {
      host = nodes.charlie;
      port = 2342;
      dashy.section = "monitoring";
      dashy.description = "View logs and metrics";
      dashy.icon = "hl-grafana";
      modules = [ "prometheusStack" "prometheusStack.grafana" ];
    };

    loki = {
      host = nodes.charlie;
      port = 3100;
      blackbox.path = "/ready";
      modules = [ "prometheusStack" "prometheusStack.loki" ];
    };

    lubelogger = {
      host = nodes.charlie;
      port = 5000;
      modules = [ "lubelogger" ];
    };

    nodeExporter = { port = 9002; };

    minio = {
      host = nodes.dee;
      port = 9100;
      consolePort = 9101;
      modules = [ "minio" ];
    };

    "ui.minio" = {
      host = nodes.dee;
      port = services.minio.consolePort;
      dashy.section = "storage";
      dashy.description = "S3 compatible object storage";
      dashy.icon = "hl-minio";
      modules = [ "minio" ];
    };

    obsidian = {
      host = nodes.charlie;
      port = 3050;
      modules = [ "backup.obsidian" ];
    };

    portainer = {
      host = nodes.frank;
      port = 9000;
      dashy.section = "virtualisation";
      dashy.description = "Frontend for containers";
      dashy.icon = "hl-portainer";
    };

    prometheus = {
      host = nodes.dennis;
      port = 9001;
      dashy.section = "monitoring";
      dashy.description = "Polls for metrics before captured by Thanos";
      dashy.icon = "hl-prometheus";
    };

    promtail = { port = 28183; };

    proxmox = {
      host = nodes.dee;
      port = 8006;
      dashy.section = "virtualisation";
      dashy.description = "Frontend for VMs";
      dashy.icon = "hl-proxmox";
    };

    plex = {
      host = nodes.dee;
      port = 32400;
      dashy.section = "media";
      dashy.description = "Watch TV and movies";
      dashy.icon = "hl-plex";
      modules = [ "plex" ];
    };

    thanos-query = {
      host = nodes.dennis;
      port = 19192;
      grpcPort = 10902;
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
      dashy.section = "networks";
      dashy.description = "UniFi controller";
      dashy.icon = "hl-unifi-controller";
      modules = [ "unifi" ];
    };

    victoriametrics = {
      host = nodes.charlie;
      port = 8428;
      dashy.section = "monitoring";
      dashy.description = "Alternate poller of metrics in PromQL format";
      dashy.icon = "https://avatars.githubusercontent.com/u/43720803";
      modules = [ "prometheusStack" "prometheusStack.victoriametrics" ];
    };
  };

  # Enrich servicesBase by adding the key as the name - DRY
  services = builtins.listToAttrs (map
    (serviceName: {
      name = serviceName;
      value = (servicesBase."${serviceName}" // { name = serviceName; });
    })
    (builtins.attrNames servicesBase));

  usersBase = {
    # Empty for now to allow for future changes
    jdheyburn = { };
    "joseph.heyburn" = { };
  };

  # Enrich usersBase by adding the key as the name - DRY
  users = builtins.listToAttrs (map
    (userName: {
      name = userName;
      value = (usersBase."${userName}" // { name = userName; });
    })
    (builtins.attrNames usersBase));
}
