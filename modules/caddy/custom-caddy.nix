# TODO experiment with overlays instead of this file

{ stdenv, lib, buildGo117Module, nixosTests, plugins ? [ ], fetchFromGitHub
, vendorSha256 ? "" }:

with lib;

let
  version = "2.6.2";

  dist = fetchFromGitHub {
    owner = "caddyserver";
    repo = "dist";
    rev = "v${version}";
    sha256 = "sha256-bctRc2klaV2JbB4KRWk5n/ACQ/7KlgaMKHae7SIQs+0=";
  };

  imports = flip concatMapStrings plugins (pkg: "			_ \"${pkg}\"\n");

  main = ''
    		package main
    	
    		import (
    			caddycmd "github.com/caddyserver/caddy/v2/cmd"

    			_ "github.com/caddyserver/caddy/v2/modules/standard"
    ${imports}
    		)

    		func main() {
    			caddycmd.Main()
    		}
    	'';

in buildGo117Module rec {
  pname = "caddy";
  inherit version;

  subPackages = [ "cmd/caddy" ];

  src = fetchFromGitHub {
    owner = "caddyserver";
    repo = "caddy";
    rev = "v${version}";
    sha256 = "sha256-Z9A2DRdX0LWjIKdHAHk2IRxsUzvC90Gf5ohFLXNHcsw=";
  };

  inherit vendorSha256;

  overrideModAttrs = (_: {
    preBuild = ''
      echo '${main}' > cmd/caddy/main.go
    '';
    postInstall = ''
      cp go.sum go.mod $out/ && ls $out/
    '';
  });

  postPatch = ''
    echo '${main}' > cmd/caddy/main.go
    cat cmd/caddy/main.go
  '';

  postConfigure = ''
    cp vendor/go.sum ./
    cp vendor/go.mod ./
  '';

  postInstall = ''
    install -Dm644 ${dist}/init/caddy.service ${dist}/init/caddy-api.service -t $out/lib/systemd/system
    substituteInPlace $out/lib/systemd/system/caddy.service --replace "/usr/bin/caddy" "$out/bin/caddy"
    substituteInPlace $out/lib/systemd/system/caddy-api.service --replace "/usr/bin/caddy" "$out/bin/caddy"
  '';

  passthru.tests = { inherit (nixosTests) caddy; };

  meta = with lib; {
    homepage = "https://caddyserver.com";
    description = "Fast, cross-platform HTTP/2 web server with automatic HTTPS";
    license = licenses.asl20;
    maintainers = with maintainers; [ Br1ght0ne techknowlogick ];
  };
}

