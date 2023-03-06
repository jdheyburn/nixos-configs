{
  description = "A very basic flake";

  inputs = {
    agenix.url = "github:ryantm/agenix";
    argononed = {
      url = "gitlab:DarkElvenAngel/argononed";
      flake = false;
    };

    darwin.url = "github:lnl7/nix-darwin";
    darwin.inputs.nixpkgs.follows = "nixpkgs";

    deploy-rs.url = "github:serokell/deploy-rs";

    flake-utils.url = "github:numtide/flake-utils";
    flake-utils.inputs.nixpkgs.follows = "nixpkgs";

    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    nixpkgs.url = "nixpkgs/nixos-unstable";
    nixpkgs-2205.url = "nixpkgs/nixos-22.05";
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";
  };

  outputs = inputs@{ self, argononed, agenix, darwin, flake-utils, home-manager, nixpkgs
    , nixpkgs-2205, nixos-hardware, deploy-rs, ... }:
    let
      inherit (flake-utils.lib) eachSystemMap system;
      catalog = import ./catalog.nix { inherit nixos-hardware; };

      # Modules to import to hosts
      ## Common modules to apply to everything
      common = [ ./common agenix.nixosModules.default ];
      ## Modules under ./modules
      nixosModules = builtins.listToAttrs (map (module: {
        name = module;
        value = import (./modules + "/${module}");
      }) (builtins.attrNames (builtins.readDir ./modules)));
      ## home-manager modules and users
      ## Need to verify this works as expected for non-nixOS hosts
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
      # End of modules

      # Function to create a nixosSystem
      mkLinuxSystem = system: extraModules:
        nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = {
            inherit catalog;
            flake-self = self;
          } // inputs;
          modules = common ++ [{ imports = builtins.attrValues nixosModules; }]
            ++ homeFeatures system ++ extraModules;
        };

      hosts = builtins.attrNames (builtins.readDir ./hosts);
    in {

      overlays.default = final: prev: (import ./overlays inputs) final prev;

      # No fancy nixlang stuff here like in nixosConfigurations, there's only one host
      # and I'm just playing around with it for the time being
      darwinConfigurations."macbook" = darwin.lib.darwinSystem {
          system = "x86_64-darwin";
          modules = [
            ./hosts/macbook/configuration.nix
            home-manager.darwinModules.home-manager {
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              home-manager.users."joseph.heyburn" = {
                imports = [ ./home-manager/common.nix ./home-manager/users/jdheyburn ];
              };
            }
          ];
        };

      nixosConfigurations = builtins.listToAttrs (map (host:
        let
          node = catalog.nodes.${host};
          modules = [ (./hosts + "/${host}/configuration.nix") ]
            ++ nixpkgs.lib.optional (node ? "nixosHardware") node.nixosHardware;
        in {
          name = host;
          value = mkLinuxSystem node.system modules;
        }) hosts);

      # deploy-rs configs - built off what exists in ./hosts and in catalog.nix
      deploy.nodes = builtins.listToAttrs (map (host:
        let node = catalog.nodes.${host};
        in {
          name = host;
          value = {
            hostname = node.ip.private;
            profiles.system = {
              user = "root";
              path = deploy-rs.lib.${node.system}.activate.nixos
                self.nixosConfigurations.${host};
              sshOpts = [ "-o" "IdentitiesOnly=yes" ];
            };
          };
        }) hosts);

      checks = builtins.mapAttrs
        (system: deployLib: deployLib.deployChecks self.deploy) deploy-rs.lib;

      # allows nix fmt
      # TODO format code in separate PR
      # formatter.x86_64-darwin = nixpkgs.legacyPackages.x86_64-darwin.nixpkgs-fmt;
    };
}

