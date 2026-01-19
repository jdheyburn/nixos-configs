# nixos-configs

My repository containing my Nix configurations across NixOS, nix-darwin (macOS), and home-manager.

- NixOS is used to configure system parameters on NixOS hosts
- nix-darwin is used to configure system parameters on the MacBooks I have
- home-manager is used to configure user level parameters across both NixOS and nix-darwin

This means this repo acts as a monorepo of sorts for all my configs for both system and users, with the goal to keep things DRY.

## Layout

The bulk of the work to coalesce everything together is done in `flake.nix`. See below for a high level on what each directory structure does.

### modules

Modules are what make Nix so awesome, by abstracting away the concrete details of how to configure and deploy a service.

I split my modules based on whether it is meant to be deployed via `nix-darwin` or `nixos`. I may consider adding a section for home-manager modules too.

```text
modules
├── darwin
│   ├── ghostty
│   └── window-tiling
├── nixos
│   ├── actualbudget
│   ├── aria2
│   ├── backup
│   ├── caddy
# ...
```

These modules can then be referenced in host configurations.

### hosts

```text
hosts
├── darwin
│   ├── common
│   ├── macbook
│   └── mbp
└── nixos
    ├── charlie
    ├── common
    ├── dee
    ├── dennis
    └── mac
```

Similarly for modules, I split out hosts by `nix-darwin` and `nixos`. The `common` dir in each of them contains configs that get applied to all hosts of that system.

I don't have a common set of configs across these two... yet.

### home

This is where home-manager configs live.

```text
home
├── common
│   ├── cli
│   ├── default.nix
│   ├── git
│   ├── hyper
│   ├── neovim
│   ├── tmux
│   └── zsh
├── modules
│   ├── beets
│   ├── kubernetes-client
│   ├── ssh-client
│   └── vscode
├── profiles
│   ├── desktop
│   └── server
└── users
    ├── jdheyburn
    ├── joseph.heyburn
    └── root
```

`common` is deployed to all users. This is split out more so such as `git`, `tmux`, etc., so as to keep file lengths reasonable.

`modules` are present here too, as not all the users will want these. For example, not every user needs Kubeernetes CLI stuff.

`profiles` exist here for allocating profiles to hosts that make logical sense. I'm not doing anything with these yet, but the idea is that all GUI modules would be declared in `desktop`.

`users` are where user configs are defined. This has an extra directory to provide configs that should apply only to users on particular hosts.

```text
home/users/jdheyburn
├── default.nix
└── hosts
    ├── dee
    └── mbp
```

### lib

Any functions that get declared across the configs go here.

## Catalog

`catalog.nix` is a global state file. The idea is that anything that is shared across nodes is defined here so that they can build their respective configs.

### Services

Services is a mapping of service name to service attributes, it can accept:

- `host`
  - The node that runs this service
- `port`
  - Port this service runs on
- `modules`
  - A list of strings containing the modules to check on the desired host to see if its enabled
    - e.g. `[ "prometheusStack" "prometheusStack.grafana" ]`
    - Downstream dependencies resolve to true if both `modules.prometheusStack.enable` and `modules.prometheusStack.grafana.enable` are true
  - Used to determine whether:
    - DNS rewrite entry is created on the DNS server
    - Blackbox exporter should perform healthchecks against it
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

### Hosts

- dee
  - Raspberry Pi 4 4GB
- charlie
  - hetzner VPS server
- mac
  - hetzner server auction that comes and goes
- macbook
  - MBP with nix-darwin
- mbp
  - my own MBP for home

Hosts are defined in `nodes`, which can have these attributes:

- `ip.private`
  - Private IP address
- `ip.tailscale`
  - IP address as tailscale sees it
- `system`
  - What system architecture is this host
  - Also used to determine if it is a nixOS or darwin (macOS) machine
- `nixosHardware`
  - Any [nixos-hardware](https://github.com/NixOS/nixos-hardware) flakes that should be included on this host
- `shouldScrape`
  - If Prometheus should scrape this node for metrics
  - This is only temporary while I decom the non-NixOS hosts (TODO)
- `users`
  - list of users that should have home-manager configurations enabled for

### Users

The idea for these is to specify within the catalog what users should be created on the hosts.

Users are defined as attribute sets, although I don't do anything with this yet.

## Deployment

[deploy-rs](https://github.com/serokell/deploy-rs) is used to deploy the configurations.

```bash
# all hosts
nix run github:serokell/deploy-rs -- -s "."

# per host
nix run github:serokell/deploy-rs -- -s ".#dee"

# more explicit parameters
nix run github:serokell/deploy-rs -- --keep-result --auto-rollback false --magic-rollback false --activation-timeout 3600 -s ".#dee"
```

## Runbooks

### Upgrading to latest versions

1. Update nix flake

    ```bash
    nix flake upgrade
    ```

2. Check for anywhere `version` is being hardcoded and update them

### Adding secrets

Secrets are managed by [agenix](https://github.com/ryantm/agenix).

1. Ensure the host or user you're on has it's public key added to `secrets/secrets.nix`, look in `/etc/ssh/ssh_host_ed25519_key.pub`.

2. cd to `secrets`

3. Execute `nix run github:ryantm/agenix -- -e FILENAME.age`

4. Add the file to git so that flakes can see it

5. Reference the secret where you need it, i.e.:

```nix
age.secrets."healthchecks-secrets-file" = {
  file = myUtils.secrets.file "healthchecks-secrets-file";
  owner = "healthchecks";
  group = "healthchecks";
};

mySecretFile = config.age.secrets."healthchecks-secrets-file".path;
```

### Setting null sha256

Explicitly setting the sha256 attribute to an empty string will have Nix assume no validation.

It will then error on a hash mismatch, so copy the actual hash and paste it in the empty string.

```nix
sha256 = "";
```

## Manual macOS settings

There are some settings which as of writing are not configurable in nix-darwin. The list below keeps a track of what they are:

- Enable Mission Control shortcuts
  - Keyboard -> Keyboard shortcuts -> Mission Control -> Check all
- Reduce motion
  - Accessibility -> Display -> Check `Reduce motion`
- Mission Control settings
  - No Space rearranging
    - Desktop & Dock -> Mission Control -> Uncheck `Automatically rearrange Spaces based on most recent use`
  - Desktop & Dock -> Mission Control -> Uncheck `When switching to an application, switch to a Space with open windows for the application`
- Don't use the weird Apple quotes
  - Keyboard -> Input Sources -> Change `For (double|single) quotes`
- Turn off keyboard backlight after inactvity
  - Keyboard -> Turn keyboard backlight off after inactivity -> `After 1 Minute`

## Tips

- [Go here](https://discourse.nixos.org/t/what-is-the-latest-best-practice-to-prefetch-the-hash/22103/4) for how blank hashes are structured
- If after updating there are complaints about options no longer present, it's likely that they are no longer available, so they need to be removed
- You can use `nixos-option` to find what options are available, and their specification

## Credits / Inspiration

Resources that I've used to help create the repo, please follow them as they are more talented engineers than I!

- https://github.com/barrucadu/nixfiles
- https://github.com/jhillyerd/homelab
- https://github.com/pinpox/nixos
