# Catalog defines the systems & services on my network.
# Inspired from https://github.com/jhillyerd/homelab/blob/main/nixos/catalog.nix
{ system }: rec {

  nodes = {
    dee = {
      ip.private = "192.168.1.10";
      ip.tailscale = "";
      system = system.aarch64-linux;
    };

    dennis = {
      ip.private = "192.168.1.12";
      ip.tailscale = "";
      system = system.x86_64-linux;
    };

  };

  services = {

    grafana = { port = 2342; };

    loki = { port = 3100; };

    nodeExporter = { port = 9002; };

    prometheus = { port = 9001; };

  };

}

