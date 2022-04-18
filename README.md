# nixos-configs

A place for me to dump nix configs

## Hosts

- dee
  - Raspberry Pi 4 4GB
  - Replaced dee_rpi3
- dennis
  - VM on a Proxmox hypervisor

## Building

Once set up with flakes, it should be able to read the config from the hostname assigned to the machine:

```bash
sudo nixos-rebuild switch
```

Should it not detect the hostname, or that hasn't been set, you can specify the host to target with:

```bash
sudo nixos-rebuild build --flake '/etc/nixos#HOSTNAME'
```

## Credits / Inspiration

Resources that I've used to help create the repo, please follow them as they are more talented engineers than I!

- https://github.com/barrucadu/nixfiles
  - Initial setup
- https://github.com/srid/nixos-config
  - For converting to flakes
