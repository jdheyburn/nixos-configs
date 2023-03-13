# nixos-configs

A place for me to dump nix configs

## Deployment

[deploy-rs]() is used to deploy the configurations.

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
- `caddify.enable`
  - Whether Caddy configs should be created
  - Also used by DNS module to create a rewrite entry
- `caddify.skip_tls_verify`
  - Whether Caddy should ignore TLS verification when forwarding traffic to this service
  - Usually for when the backend service is on HTTPS, and I cba to set up certificate trust
- `caddify.forwardTo`
  - Define a node name here different to host to have that node set up reverse proxy instead
  - Currently I'm using this to reverse proxy for services where nodes do not have Caddy on them (i.e. non-NixOS nodes)
- `caddify.paths`
  - A list of paths, additional path forwarding to ports that
  - Used this for testing path forwarding for minio console, reverted as it didn't play nice
  - `path`
    - The URL path to forward (e.g. `/ui/*`)
  - `port`
    - The port to forward to
- `dashy.section`
  - What section in dashy it should fall under
- `dashy.description`
  - The description to use in dashy
- `dashy.icon`
  - The icon to display in dashy

## Hosts

- dee
  - Raspberry Pi 4 4GB
  - Replaced dee_rpi3
- dennis
  - VM on a Proxmox hypervisor

## Runbooks

### Upgrading to latest versions

1. Update nix flake

    ```bash
    nix flake upgrade
    ```

2. Update overlays
    - healthchecks
    - plex

3. Update container images
    - dashy

## Credits / Inspiration

Resources that I've used to help create the repo, please follow them as they are more talented engineers than I!

- https://github.com/barrucadu/nixfiles
- https://github.com/jhillyerd/homelab
- https://github.com/pinpox/nixos
- https://github.com/shaunsingh/nix-darwin-dotfiles
