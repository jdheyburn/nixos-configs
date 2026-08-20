#!/usr/bin/env bash
# Update windmill-cli to the latest npm release.
#
# The published npm tarball ships no lockfile, so package.nix supplies a
# manually generated package-lock.json. That lockfile is version-specific and
# must be regenerated BEFORE nix-update computes npmDepsHash, or the hash will
# not match the new dependency closure. Sequence:
#   1. resolve latest version from the npm registry
#   2. regenerate package-lock.json for that version
#   3. nix-update sets version + src hash + npmDepsHash
set -euo pipefail

pkg_dir="home/users/joseph.heyburn/windmill-cli"
[[ -d "$pkg_dir" ]] || { echo "error: run this from the repo root (can't find $pkg_dir)" >&2; exit 1; }

echo "==> Resolving latest windmill-cli version from npm"
latest="$(nix run nixpkgs#curl -- -fsSL https://registry.npmjs.org/windmill-cli \
  | nix run nixpkgs#jq -- -r '."dist-tags".latest')"
echo "    latest = ${latest}"

echo "==> Regenerating package-lock.json for windmill-cli@${latest}"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
# Fetch the package.json from the npm registry so that the lockfile is
# generated with windmill-cli as the root package (not as a dependency).
nix run nixpkgs#curl -- -fsSL "https://registry.npmjs.org/windmill-cli/${latest}" \
  | nix run nixpkgs#jq -- '{name, version, license, dependencies, optionalDependencies, bin}' \
  > "$tmp/package.json"
# npm ships with nixpkgs#nodejs; run it via `nix shell … --command` so nothing
# needs pre-installing. --package-lock-only writes only the lockfile.
( cd "$tmp" && nix shell nixpkgs#nodejs --command \
    npm install --package-lock-only --ignore-scripts >/dev/null )
cp "$tmp/package-lock.json" "$pkg_dir/package-lock.json"

echo "==> Running nix-update (version + src hash + npmDepsHash)"
nix run nixpkgs#nix-update -- --flake --version "$latest" windmill-cli

echo "==> Done. Review with: git diff ${pkg_dir}"
