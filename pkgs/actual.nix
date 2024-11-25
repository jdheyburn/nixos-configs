{ lib, config, pkgs, ... }:


with import <nixpkgs> { };
with lib;

let
  cfg = config.services.actual;
  actual = pkgs.stdenv.mkDerivation (finalAttrs: {
    name = "actual-server";
    version = "24.8.0";
    src = pkgs.fetchFromGitHub {
      owner = "actualbudget";
      repo = "actual-server";
      rev = "v${version}";
      sha256 = "sha256-0AiUsO+jK3F+ClBVSzngKSHanQO5w+DQfDKvWVHCnSo=";
    };

    nativeBuildInputs = with pkgs; [
      nodejs
      python3
      jq
      moreutils
      makeWrapper
      yarn-berry
    ];

    yarnOfflineCache = pkgs.stdenvNoCC.mkDerivation {
      name = "actual-deps";
      nativeBuildInputs = with pkgs; [ yarn-berry ];
      inherit (finalAttrs) src;

      NODE_EXTRA_CA_CERTS = "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt";

      supportedArchitectures = builtins.toJSON {
        os = [ "darwin" "linux" ];
        cpu = [ "arm" "arm64" "ia32" "x64" ];
        libc = [ "glibc" "musl" ];
      };

      configurePhase = ''
        runHook preConfigure

        export HOME="$NIX_BUILD_TOP"
        export YARN_ENABLE_TELEMETRY=0

        yarn config set enableGlobalCache false
        yarn config set cacheFolder $out
        yarn config set supportedArchitectures --json "$supportedArchitectures"

        runHook postConfigure
      '';

      buildPhase = ''
        runHook preBuild

        mkdir -p $out
        yarn install --immutable --mode skip-build

        runHook postBuild
      '';

      dontInstall = true;

      outputHashAlgo = "sha256";
      outputHash = "sha256-B9H/r22qu6GXIJ/B1VE17sn07hveD3QCCuODAdvIK/A=";
      outputHashMode = "recursive";
    };

    patchPhase = ''
      sed -i '1i#!${pkgs.nodejs}/bin/node' app.js
    '';

    configurePhase = ''
      runHook preConfigure

      export HOME="$NIX_BUILD_TOP"
      export YARN_ENABLE_TELEMETRY=0
      export npm_config_nodedir=${pkgs.nodejs}

      yarn config set enableGlobalCache false
      yarn config set cacheFolder $yarnOfflineCache

      runHook postConfigure
    '';

    buildPhase = ''
      runHook preBuild

      yarn install --immutable --immutable-cache
      yarn build
      yarn workspaces focus --all --production

      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall

      mkdir -p $out/{bin,lib}

      mkdir $out/lib/actual
      cp -r package.json app.js src migrations node_modules $out/lib/actual/

      chmod +x $out/lib/actual/app.js

      makeWrapper $out/lib/actual/app.js $out/bin/actual --chdir $out/lib/actual

      runHook postInstall
    '';

    fixupPhase = ''
      runHook preFixup

      patchShebangs $out/lib

      runHook postFixup
    '';
  });
  dataDir = "/var/lib/actual";
  cfgFile = pkgs.writeText "actual.json" (builtins.toJSON {
    inherit dataDir;
    inherit (cfg) hostname port;
    serverFiles = "${dataDir}/server-files";
    userFiles = "${dataDir}/user-files";
  });
in
{
  options.services.actual = {
    enable = mkEnableOption "Actual budget server";
    hostname = mkOption { type = types.str; default = "127.0.0.1"; };
    port = mkOption { type = types.port; default = 5006; };
  };
  config = mkIf cfg.enable {
    users.users.actual = {
      name = "actual";
      group = "actual";
      isSystemUser = true;
    };

    users.groups.actual = { };

    systemd.services.actualServer = {
      description = "Actual budget server";
      documentation = [ "https://actualbudget.org/docs/" ];
      wantedBy = [ "multi-user.target" ];
      after = [ "networking.target" ];
      serviceConfig = {
        ExecStart = "${actual}/bin/actual";
        Restart = "always";
        User = "actual";
        Group = "actual";
        PrivateTmp = true;
        #StateDirectory = "actual";
      };
      environment.ACTUAL_CONFIG_PATH = "${cfgFile}";
    };
  };
}

