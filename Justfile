# List available recipes
default:
    @just --list

# Full update: flake inputs, then hand-maintained packages. Review the diff before committing.
update: update-flake update-nix-pkgs update-containers

# Bump flake inputs (nixpkgs et al.). --refresh re-resolves mutable refs (e.g.
# the unpinned llm-agents input tracking main) so fast-churn inputs can't be
# served a stale cached rev and jump backward to an older commit.
update-flake:
    nix flake update --refresh

# Bump hand-maintained Nix source packages (windmill-cli, beetcamp)
update-nix-pkgs:
    ./update/windmill-cli.sh
    nix run nixpkgs#nix-update -- --flake beetcamp

# Bump pinned OCI image tags (dashy, lubelogger). Pass --dry-run to preview.
update-containers *ARGS:
    uv run update/containers.py {{ARGS}}
