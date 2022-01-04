{ stdenv, lib, buildGoModule, plugins ? [], fetchFromGitHub, vendorSha256 ? "" }:

with lib;

let imports = flip concatMapStrings plugins (pkg: "\t\t\t_ \"${pkg}\"\n");

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


in buildGoModule rec {
	pname = "caddy";
	version = "2.4.6";

	#goPackagePath = "github.com/caddyserver/caddy/v2";

	subPackages = [ "cmd/caddy" ];

	#src = builtins.fetchGit {
	#	url = "https://github.com/caddyserver/caddy.git";
	#	rev = "e7457b43e4703080ae8713ada798ce3e20b83690"; # v2.4.6
	#};

        src = fetchFromGitHub {
          owner = "caddyserver";
          repo = "caddy";
          rev = "v${version}";
          #sha256 = "1xp2j3gy7h38j2h1r1yfrz3jwprvby192zjzb3y4hpk9hg7b3l64";
          sha256 = "sha256-xNCxzoNpXkj8WF9+kYJfO18ux8/OhxygkGjA49+Q4vY=";
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

	meta = with lib; {
		homepage = "https://caddyserver.com";
		description = "Fast, cross-platform HTTP/2 web server with automatic HTTPS";
		license = licenses.asl20;
		maintainers = with maintainers; [ rushmorem fpletz zimbatm ];
	};
}
