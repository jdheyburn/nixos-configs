{
  description = "A very basic flake";

  inputs = {
    agenix.url = "github:ryantm/agenix";
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    nixpkgs.url = "nixpkgs/nixos-unstable";
    nixpkgs-2205.url = "nixpkgs/nixos-22.05";
    nixos-hardware.url = github:NixOS/nixos-hardware/master;
  };

  outputs = inputs@{ self, agenix, home-manager, nixpkgs, nixpkgs-2205, nixos-hardware, ... }:
    let
      common = [
        # TODO change my modules to default.nix, then loop over
        # directories 
        ./common.nix
        agenix.nixosModule
        ./modules/prometheus-stack/prometheus-stack.nix
        ./modules/backup-small-files.nix
        ./modules/backup-usb.nix
        ./modules/caddy/caddy.nix
        ./modules/dns.nix
        ./modules/monitoring.nix
        ./modules/nfs.nix
        ./modules/plex.nix
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
          specialArgs = { inherit system inputs; };
          modules = common ++ homeFeatures system ++ extraModules;
        };
      mkLinuxSystemDee = system: extraModules:
        nixpkgs-2205.lib.nixosSystem {
          inherit system;
          specialArgs = { inherit system inputs; };
          modules = common ++ homeFeatures system ++ extraModules;
        };
    in {

      nixosConfigurations = {
        dennis =
          mkLinuxSystem "x86_64-linux" [ ./hosts/dennis/configuration.nix ];

        dee =
          mkLinuxSystemDee "aarch64-linux" [ ./hosts/dee/configuration.nix nixos-hardware.nixosModules.raspberry-pi-4];

      };

    };
}

