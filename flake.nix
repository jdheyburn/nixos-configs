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
          home-manager.extraSpecialArgs = { 
            inherit system inputs; 
          };
          home-manager.users.jdheyburn = {
            imports = [ ./home-manager.nix ];
          };
        }
      ];
     mkLinuxSystem = system: extraModules:
       nixpkgs.lib.nixosSystem {
         inherit system;
         pkgs = nixpkgs.legacyPackages.${system};
         specialArgs = {
          inherit system inputs;
        };
         modules = common ++ homeFeatures system ++ extraModules;
       };
    in {

      nixosConfigurations = {
                dennis = mkLinuxSystem "x86_64-linux" [
                  ./hosts/dennis/configuration.nix
                ];
      
      dee = mkLinuxSystem "aarch64-linux" [ ./hosts/dee/configuration.nix ];

    #    dennis = nixpkgs.lib.nixosSystem {
    #      system = "x86_64-linux";
    #      pkgs = nixpkgs.legacyPackages."x86_64-linux";
    #      specialArgs = { inherit inputs; };
    #      modules = common ++ homeFeatures ++ [
    #        ./hosts/dennis/configuration.nix
    #      ];
    #    };

      #  dee = nixpkgs.lib.nixosSystem {
      #    #system = "aarch64-linux";
      #    pkgs = nixpkgs.legacyPackages."aarch64-linux";
      #    specialArgs = { inherit inputs; };
      #    modules = common ++ [
      #      home-manager.nixosModules.home-manager
      #      {
      #        # Fixes https://github.com/divnix/digga/issues/30
      #        home-manager.useGlobalPkgs = true;
      #        home-manager.extraSpecialArgs = {
      #          inherit inputs;
      #          system = "aarch64-linux";
      #        };
      #        home-manager.users.jdheyburn = {
      #          imports = [ ./home/home-manager.nix ];
      #        };
      #      }
      #    ] ++ [
      #      ./hosts/dee/configuration.nix
      #      ./modules/backup.nix
      #      ./modules/caddy/caddy.nix
      #      ./modules/dns.nix
      #      ./modules/monitoring.nix
      #      ./modules/nfs.nix
      #      ./modules/unifi.nix
      #    ];
      #  };

      };

    };
}

