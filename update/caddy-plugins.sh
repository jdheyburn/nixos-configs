#!/usr/bin/env bash
# Update the Caddy cloudflare DNS plugin tag and the withPlugins hash.
#
# The withPlugins hash covers the Caddy source plus the plugins' vendored Go
# modules, so it changes when either the plugin tag or Caddy itself moves.
# update-flake can bump Caddy through nixpkgs, so run this after it and let it
# recompute the hash even when the plugin tag is already current. Sequence:
#   1. resolve the latest plugin tag from the upstream git repo
#   2. build the plugin source with the current hash, against the locked nixpkgs
#   3. on a hash mismatch, write the "got:" hash back into the module
set -euo pipefail

file="modules/nixos/caddy/default.nix"
module="github.com/caddy-dns/cloudflare"
[[ -f "$file" ]] || { echo "error: run this from the repo root (can't find $file)" >&2; exit 1; }

echo "==> Resolving latest ${module} tag"
latest="$(git ls-remote --tags --refs "https://${module}" \
  | sed -nE 's|.*refs/tags/(v[0-9]+\.[0-9]+\.[0-9]+)$|\1|p' \
  | sort -V | tail -n1)"
[[ -n "$latest" ]] || { echo "error: no vX.Y.Z tags found for ${module}" >&2; exit 1; }
current="$(sed -nE "s|.*\"${module}@([^\"]+)\".*|\1|p" "$file")"
old_hash="$(sed -nE 's|.*hash = "(sha256-[^"]+)";.*|\1|p' "$file")"
echo "    current = ${current}, latest = ${latest}"

# Build against the flake's locked nixpkgs for this machine's system. The
# vendored source is the same on every platform, so a hash computed on macOS
# matches the one the NixOS hosts need. If the output is already in the store
# with the current hash, nothing is built.
rev="$(nix run nixpkgs#jq -- -r '.nodes[.nodes.root.inputs.nixpkgs].locked.rev' flake.lock)"
echo "==> Checking withPlugins hash against nixpkgs ${rev:0:7}"
if out="$(nix build --impure --no-link --expr "
  let pkgs = (builtins.getFlake \"github:NixOS/nixpkgs/${rev}\").legacyPackages.\${builtins.currentSystem};
  in (pkgs.caddy.withPlugins {
    plugins = [ \"${module}@${latest}\" ];
    hash = \"${old_hash}\";
  }).src
" 2>&1)"; then
  new_hash="$old_hash"
else
  new_hash="$(sed -nE 's|^[[:space:]]*got:[[:space:]]*(sha256-[^[:space:]]+).*|\1|p' <<<"$out" | head -n1)"
  [[ -n "$new_hash" ]] || { echo "$out" >&2; echo "error: build failed without a hash mismatch" >&2; exit 1; }
fi

if [[ "$current" == "$latest" && "$new_hash" == "$old_hash" ]]; then
  echo "    already up to date, nothing to do"
  exit 0
fi

echo "    plugin ${current} -> ${latest}"
echo "    hash   ${old_hash} -> ${new_hash}"
sed -i.bak -E \
  -e "s|\"${module}@[^\"]+\"|\"${module}@${latest}\"|" \
  -e "s|hash = \"sha256-[^\"]+\";|hash = \"${new_hash}\";|" \
  "$file"
rm "$file.bak"

echo "==> Done. Review with: git diff ${file}"
