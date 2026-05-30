{ lib, buildNpmPackage, fetchFromGitHub, nodejs_22, python3, pkg-config }:

buildNpmPackage rec {
  pname = "obsidian-headless";
  version = "0.0.6";

  src = fetchFromGitHub {
    owner = "obsidianmd";
    repo = "obsidian-headless";
    rev = "v${version}";
    # Update hash with: nix-prefetch-github obsidianmd obsidian-headless --rev v${version}
    hash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
  };

  nodejs = nodejs_22;
  nativeBuildInputs = [ python3 pkg-config ];

  # Update after fetching source: cd <src> && nix run nixpkgs#prefetch-npm-deps -- package-lock.json
  npmDepsHash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";

  meta = with lib; {
    description = "Headless client for Obsidian Sync";
    homepage = "https://obsidian.md";
    license = licenses.unfree;
    mainProgram = "ob";
  };
}
