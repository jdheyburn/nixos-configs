# List available recipes
default:
    @just --list

# Apply this host's config (darwin-rebuild on macOS, nixos-rebuild on NixOS).
# host defaults to the machine's short hostname.
switch host=`hostname -s`:
    sudo {{ if os() == "macos" { "darwin-rebuild" } else { "nixos-rebuild" } }} switch --flake .#{{host}}

# Full update: flake inputs, then hand-maintained packages. Review the diff before committing.
update: update-flake update-nix-pkgs update-containers update-caddy-plugins

# Bump flake inputs (nixpkgs et al.). --refresh re-resolves mutable refs (e.g.
# the unpinned llm-agents input tracking main) so fast-churn inputs can't be
# served a stale cached rev and jump backward to an older commit.
update-flake:
    nix flake update --refresh

# Bump hand-maintained Nix source packages (windmill-cli, beetcamp, readwise-cli)
update-nix-pkgs:
    ./update/windmill-cli.sh
    nix run nixpkgs#nix-update -- --flake beetcamp
    nix run nixpkgs#nix-update -- --flake readwise-cli

# Bump pinned OCI image tags (dashy, lubelogger). Pass --dry-run to preview.
update-containers *ARGS:
    uv run update/containers.py {{ARGS}}

# Bump the Caddy cloudflare plugin and recompute its hash (run after update-flake)
update-caddy-plugins:
    ./update/caddy-plugins.sh

# Run the update/ and Obsidian backup script tests
test:
    uv run --with pytest pytest update/ modules/nixos/backup/obsidian/
