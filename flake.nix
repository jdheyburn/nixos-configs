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
      catalog = import ./catalog.nix { inherit nixos-hardware system; };
      common = [ ./common agenix.nixosModule ];
      homeFeatures = system: [
        home-manager.nixosModules.home-manager
        {
          # Fixes https://github.com/divnix/digga/issues/30
          home-manager.useGlobalPkgs = true;
          home-manager.extraSpecialArgs = { inherit system inputs; };

          # Builds user list from directories under /home-manager/users
          home-manager.users = builtins.listToAttrs (map (user: {
            name = user;
            value = {
              imports = [
                ./home-manager/common.nix
                (./home-manager/users + "/${user}")
              ];
            };
          }) (builtins.attrNames (builtins.readDir ./home-manager/users)));
        }
      ];

      nixosModules = builtins.listToAttrs (map (module: {
        name = module;
        value = import (./modules + "/${module}");
      }) (builtins.attrNames (builtins.readDir ./modules)));

      mkLinuxSystem = system: extraModules:
        nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = { inherit argononed catalog system inputs; };
          modules = common ++ [{ imports = builtins.attrValues nixosModules; }]
            ++ homeFeatures system ++ extraModules;
        };
    in {

      nixosConfigurations = builtins.listToAttrs (map (host:
        let
          node = catalog.nodes.${host};
          modules = [ (./hosts + "/${host}/configuration.nix") ]
            ++ (if node ? "nixosHardware" then [ node.nixosHardware ] else [ ]);
        in {
          name = host;
          value = mkLinuxSystem catalog.nodes.${host}.system modules;
        }) (builtins.attrNames (builtins.readDir ./hosts)));

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

