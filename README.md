# nixos-configs

A place for me to dump nix configs

## Deployment

[deploy-rs](https://github.com/serokell/deploy-rs) is used to deploy the configurations.

```bash
# all hosts
nix run github:serokell/deploy-rs -- -s "."

# per host
nix run github:serokell/deploy-rs -- -s ".#dennis"
```

## Catalog

`catalog.nix` is a global state file of sorts. The idea is that anything that is shared across nodes is defined here so that they can build their respective configs.

### Services

Services is a mapping of service name to service attributes, it can accept:

- `host`
  - The node that runs this service
- `port`
  - Port this service runs on
- `dns.enable`
  - Whether a DNS rewrite entry should be created on the DNS server
  - i.e. gives the service a `$SERVICE.svc.joannet.casa` hostname
- `dashy.section`
  - What section in dashy it should fall under
- `dashy.description`
  - The description to use in dashy
- `dashy.icon`
  - The icon to display in dashy
- `blackbox.name`
  - Whether the service name in healthchecks differs from the DNS name
- `blackbox.path`
  - The path that blackbox healthchecks should use, if it differs from root `/`

## Hosts

- dee
  - Raspberry Pi 4 4GB
  - Replaced dee_rpi3
- dennis
  - VM on a Proxmox hypervisor
- macbook
  - MBP with nix-darwin

Hosts are defined in `nodes`, which can have these attributes:

- `ip.private`
  - Private IP address
- `ip.tailscale`
  - IP address as tailscale sees it
- `domain`
  - If the host is on an 'external' domain to the homelab
- `shouldScrape`
  - If Prometheus should scrape this node for metrics
  - This is only temporary while I decom the non-NixOS hosts
- `isNixOS`
  - Whether this node is on NixOS or not
  - Infers some properties about the node

## Runbooks

### Upgrading to latest versions

1. Update nix flake

    ```bash
    nix flake upgrade
    ```

2. Update overlays
    - [healthchecks](https://github.com/NixOS/nixpkgs/blob/master/pkgs/servers/web-apps/healthchecks/default.nix)
    - [plex](https://github.com/NixOS/nixpkgs/tree/master/pkgs/servers/plex)

3. Update container images
    - [dashy](https://github.com/Lissy93/dashy/releases)

## Tips

- [Go here](https://discourse.nixos.org/t/what-is-the-latest-best-practice-to-prefetch-the-hash/22103/4) for how blank hashes are structured
- If after updating there are complaints about options no longer present, it's likely that they are no longer available, so they need to be removed
- You can use `nixos-option` to find what options are available, and their specification

## TODO

- Better file structure, look to flake-parts for this
  - i.e.:
    - generic Nix settings across all systems
    - generic NixOS
    - generic nix-darwin
    - host-level configs
    - generic home-manager
    - generic Linux home-manager
    - generic macOS home-manager

## Credits / Inspiration

Resources that I've used to help create the repo, please follow them as they are more talented engineers than I!

- https://github.com/barrucadu/nixfiles
- https://github.com/jhillyerd/homelab
- https://github.com/pinpox/nixos
