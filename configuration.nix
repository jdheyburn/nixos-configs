{
  imports = [
    ./common.nix
    ./home-manager.nix
    ./host/configuration.nix
    ./host/hardware-configuration.nix
    ./modules/backup.nix
    ./modules/caddy/caddy.nix
    ./modules/dns.nix
    ./modules/monitoring.nix
    ./modules/nfs.nix
    ./modules/prometheus-stack/prometheus-stack.nix
    ./modules/unifi.nix
  ];
}
