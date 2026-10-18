{ buildNpmPackage, fetchFromGitHub }:
let
  version = "0.5.10";
in
# `@readwise/cli` isn't in nixpkgs or llm-agents.nix. Unlike windmill-cli, the
# GitHub source ships its own package-lock.json, so build from the tagged
# source and let `npm run build` (tsc) produce dist/.
buildNpmPackage {
  pname = "readwise-cli";
  inherit version;

  src = fetchFromGitHub {
    owner = "readwiseio";
    repo = "readwise-cli";
    tag = "v${version}";
    hash = "sha256-/JPecz1pOs+ckwR/7DNhZ2lFr16zQlYnojLsKrSeccA=";
  };

  npmDepsHash = "sha256-IaRnzEXWkVgOyWholfDeifmP1C7xfbf5XX7bXysptmA=";

  meta = {
    description = "Command-line interface for Readwise and Reader";
    homepage = "https://github.com/readwiseio/readwise-cli";
    mainProgram = "readwise";
  };
}
