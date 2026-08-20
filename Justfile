# List available recipes
default:
    @just --list

# Full update: flake inputs, then hand-maintained packages. Review the diff before committing.
update: update-flake update-nix-pkgs update-containers

# Bump flake inputs (nixpkgs et al.)
update-flake:
    nix flake update

# Bump hand-maintained Nix source packages (windmill-cli, beetcamp)
update-nix-pkgs:
    ./update/windmill-cli.sh
    nix run nixpkgs#nix-update -- --flake beetcamp

# Bump pinned OCI image tags (dashy, lubelogger). Pass --dry-run to preview.
update-containers *ARGS:
    uv run update/containers.py {{ARGS}}
