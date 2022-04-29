{
  description = "A very basic flake";

  inputs = {
    nixpkgs.url = "nixpkgs/nixos-unstable";
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    agenix.url = "github:ryantm/agenix";
  };

  outputs = inputs@{ self, home-manager, nixpkgs, agenix, ... }:
    let
      #system = "x86_64-linux";
      #pkgs = nixpkgs.legacyPackages.${system};
      common = [ ./common.nix agenix.nixosModule ];
      #homeFeatures = [
      #  home-manager.nixosModules.home-manager
      #  {
      #    # Fixes https://github.com/divnix/digga/issues/30
      #    home-manager.useGlobalPkgs = true;
      #    home-manager.extraSpecialArgs = { inherit system inputs; };
      #    home-manager.users.jdheyburn = {
      #      imports = [ ./home/home-manager.nix ];
      #    };
      #  }
      #];
      #mkLinuxSystem = extraModules:
      #  nixpkgs.lib.nixosSystem {
      #    inherit system pkgs;
      #    specialArgs = { inherit system inputs; };
      #    modules = common ++ homeFeatures ++ extraModules;
      #  };
    in {

      nixosConfigurations = {
        # TODO need to find a way to pass in the system as a variable
        #        dennis = mkLinuxSystem [
        #          ./hosts/dennis/configuration.nix
        #          ./modules/prometheus-stack/prometheus-stack.nix
        #        ];

        #dennis = nixpkgs.lib.nixosSystem {
        #system = "x86_64-linux";
        #  pkgs = nixpkgs.legacyPackages."x86_64-linux";
        #  specialArgs = { inherit inputs; };
        #  modules = common ++ homeFeatures ++ [
        #    ./hosts/dennis/configuration.nix
        #    ./modules/prometheus-stack/prometheus-stack.nix
        #  ];
        #};

        dee = nixpkgs.lib.nixosSystem {
          #system = "aarch64-linux";
          pkgs = nixpkgs.legacyPackages."aarch64-linux";
          specialArgs = { inherit inputs; };
          modules = common ++ [
            home-manager.nixosModules.home-manager
            {
              # Fixes https://github.com/divnix/digga/issues/30
              home-manager.useGlobalPkgs = true;
              home-manager.extraSpecialArgs = {
                inherit inputs;
                system = "aarch64-linux";
              };
              home-manager.users.jdheyburn = {
                imports = [ ./home/home-manager.nix ];
              };
            }
          ] ++ [
            ./hosts/dee/configuration.nix
          ];
        };

      };

    };
}

