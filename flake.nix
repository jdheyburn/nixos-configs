{
  description = "A very basic flake";

  inputs = {
    agenix.url = "github:ryantm/agenix";
    argononed = {
      url = "gitlab:DarkElvenAngel/argononed";
      flake = false;
    };

    deploy-rs.url = "github:serokell/deploy-rs";

    flake-utils.url = "github:numtide/flake-utils";
    flake-utils.inputs.nixpkgs.follows = "nixpkgs";

    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    nixpkgs.url = "nixpkgs/nixos-unstable";
    nixpkgs-2205.url = "nixpkgs/nixos-22.05";
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";
  };

  outputs = inputs@{ self, argononed, agenix, flake-utils, home-manager, nixpkgs
    , nixpkgs-2205, nixos-hardware, deploy-rs, ... }:
    let
      inherit (flake-utils.lib) eachSystemMap system;
      catalog = import ./catalog.nix { inherit system; };
      common = [
        ./common
        agenix.nixosModule
        # TODO loop over each dir in modules
        ./modules/prometheus-stack
        ./modules/backup
        ./modules/caddy
        ./modules/dns
        ./modules/healthchecks
        ./modules/minio
        ./modules/monitoring
        ./modules/mopidy
        ./modules/navidrome
        ./modules/nfs
        ./modules/plex
        ./modules/unifi
        ./modules/victoriametrics
      ];
      homeFeatures = system: [
        home-manager.nixosModules.home-manager
        {
          # Fixes https://github.com/divnix/digga/issues/30
          home-manager.useGlobalPkgs = true;
          home-manager.extraSpecialArgs = { inherit system inputs; };
          # TODO loop over root and jdheyburn, to prevent duplicate common.nix declaration
          # TODO home-manager should be imported via dir like above
          home-manager.users.root = {
            imports = [ ./home-manager/common.nix ./home-manager/root.nix ];
          };
          home-manager.users.jdheyburn = {
            imports =
              [ ./home-manager/common.nix ./home-manager/jdheyburn.nix ];
          };
        }
      ];
      mkLinuxSystem = system: extraModules:
        nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = { inherit argononed catalog system inputs; };
          modules = common ++ homeFeatures system ++ extraModules;
        };
    in {

      nixosConfigurations = {
        # TODO should be no need to pass in hosts configuration - can it be discovered?
        dennis =
          mkLinuxSystem "x86_64-linux" [ ./hosts/dennis/configuration.nix ];

        dee = mkLinuxSystem "aarch64-linux" [
          ./hosts/dee/configuration.nix
          nixos-hardware.nixosModules.raspberry-pi-4
        ];

      };

      deploy.nodes = {
        dennis = {
          hostname = "192.168.1.12";
          profiles = {
            system = {
              user = "root";
              path = deploy-rs.lib.x86_64-linux.activate.nixos
                self.nixosConfigurations.dennis;
              sshOpts = [ "-o" "IdentitiesOnly=yes" ];
            };
          };
        };

        dee = {
          hostname = "192.168.1.10";
          profiles = {
            system = {
              user = "root";
              path = deploy-rs.lib.aarch64-linux.activate.nixos
                self.nixosConfigurations.dee;
              sshOpts = [ "-o" "IdentitiesOnly=yes" ];
            };
          };
        };

      };

      checks = builtins.mapAttrs
        (system: deployLib: deployLib.deployChecks self.deploy) deploy-rs.lib;

    };
}

