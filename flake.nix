{
  description = "A very basic flake";

  inputs = {
    nixpkgs.url = "nixpkgs/nixos-unstable";
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    agenix.url = "github:ryantm/agenix";

    forgit.url = "github:wfxr/forgit";
    forgit.flake = false;

  };

  outputs = inputs@{ self, home-manager, nixpkgs, agenix, ... }:
    let
      common = [
        ./common.nix
        agenix.nixosModule
        ./modules/prometheus-stack/prometheus-stack.nix
        ./modules/backup.nix
        ./modules/caddy/caddy.nix
        ./modules/dns.nix
        ./modules/monitoring.nix
        ./modules/nfs.nix
        ./modules/unifi.nix
      ];
      homeFeatures = system: [
        home-manager.nixosModules.home-manager
        {
          # Fixes https://github.com/divnix/digga/issues/30
          home-manager.useGlobalPkgs = true;
          home-manager.extraSpecialArgs = { inherit system inputs; };
          # TODO loop over root and jdheyburn, to prevent duplicate common.nix declaration
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
          specialArgs = { inherit system; flake-self = self; } // inputs;
          modules = common ++ homeFeatures system ++ extraModules;
        };
    in {

      overlays.default = final: prev: (import ./overlays inputs) final prev;

      nixosConfigurations = {
        dennis =
          mkLinuxSystem "x86_64-linux" [ ./hosts/dennis/configuration.nix ];

        dee = mkLinuxSystem "aarch64-linux" [ ./hosts/dee/configuration.nix ];

      };

    };
}

