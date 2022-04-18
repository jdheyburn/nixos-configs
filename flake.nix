{
  description = "A very basic flake";

  inputs = {
    nixpkgs.url = "nixpkgs/nixos-unstable";
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

  };

  outputs = inputs@{ self, home-manager, nixpkgs, ... }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
      common = [ ./common.nix ];
      homeFeatures = [
        home-manager.nixosModules.home-manager
        {
          # Fixes https://github.com/divnix/digga/issues/30
          home-manager.useGlobalPkgs = true;
          home-manager.extraSpecialArgs = { inherit system inputs; };
          home-manager.users.jdheyburn = {
            imports = [ ./home/home-manager.nix ];
          };
        }
      ];
      mkLinuxSystem = extraModules:
        nixpkgs.lib.nixosSystem {
          inherit system pkgs;
          specialArgs = { inherit system inputs; };
          modules = common ++ homeFeatures ++ extraModules;
        };
    in {

      nixosConfigurations = {
        dennis = mkLinuxSystem [
          ./hosts/dennis/configuration.nix
          ./hosts/dennis/hardware-configuration.nix
        ];
      };

    };
}
