{ buildNpmPackage, fetchurl }:
let
  version = "1.792.2";
in
# `windmill-cli` isn't in nixpkgs (only the `windmill` server is), so build
# the npm package ourselves. `npm install -g windmill-cli` provides the
# `wmill` binary — a prebuilt esbuild bundle (esm/main.js) that dynamically
# imports esbuild and loads windmill-parser-wasm-* packages at runtime, so a
# real node_modules closure has to be present.
buildNpmPackage {
  pname = "windmill-cli";
  inherit version;

  src = fetchurl {
    url = "https://registry.npmjs.org/windmill-cli/-/windmill-cli-${version}.tgz";
    hash = "sha256-1g/sU0558j1o+OQamOaHZWX6u+PZoG/G8/X6eJjM8Z4=";
  };

  # The published npm tarball ships no lockfile; supply the one generated with
  # `npm install --package-lock-only` so the dependency closure is pinned and
  # reproducible. Regenerate it (and npmDepsHash) on version bumps — the
  # update/windmill-cli.sh helper does this automatically.
  postPatch = ''
    cp ${./package-lock.json} package-lock.json
  '';

  npmDepsHash = "sha256-/yBt6hAaFXYO4jaSY6xOQJcd0JSKWpXNt5Ihez+WtZk=";

  # esbuild's postinstall downloads a platform binary over the network, which
  # the build sandbox forbids. Skipping install scripts is safe: npm still
  # installs the matching @esbuild/<platform> optional dep (which ships the
  # native binary wmill uses), and the wasm parser deps need no build step.
  npmFlags = [ "--ignore-scripts" ];

  # Prebuilt esbuild bundle (esm/main.js) — there is no build script to run.
  dontNpmBuild = true;

  meta = {
    description = "Windmill CLI (wmill)";
    homepage = "https://www.windmill.dev";
    mainProgram = "wmill";
  };
}
