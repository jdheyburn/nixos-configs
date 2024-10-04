{
  description = "A very basic flake";

  # Unsure where exactly this needs to live, as I am probably duplicating it in modules/common/default.nix too
  # It's probably required here for when I build on a non-NixOS machine
  nixConfig = {
    extra-substituters = [ "https://numtide.cachix.org" ];
    extra-trusted-public-keys =
      [ "numtide.cachix.org-1:2ps1kLBUWjxIneOy1Ik6cQjb41X0iXVXeHigGmycPPE=" ];
  };

  inputs = {
    agenix.url = "github:ryantm/agenix";
    argononed = {
      url = "gitlab:DarkElvenAngel/argononed";
      flake = false;
    };

    catppuccin.url = "github:catppuccin/nix";

    darwin.url = "github:lnl7/nix-darwin";
    darwin.inputs.nixpkgs.follows = "nixpkgs-unstable";

    deploy-rs.url = "github:serokell/deploy-rs";

    flake-utils.url = "github:numtide/flake-utils";

    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs-unstable";

    nixos-hardware.url = "github:NixOS/nixos-hardware/master";

    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";

    nixpkgs.url = "github:numtide/nixpkgs-unfree";
    nixpkgs.inputs.nixpkgs.follows = "nixpkgs-unstable";
  };

  outputs =
    { self
    , ...
    }@inputs:
      with inputs;
      let
        inherit (flake-utils.lib) eachSystemMap system;
        catalog = import ./catalog.nix { inherit nixos-hardware; };

        # Modules to import to hosts
        ## Common modules to apply to everything
        common = [ ./common agenix.nixosModules.default ];

        ## Modules under ./modules
        nixosModules = builtins.listToAttrs (map
          (module: {
            name = module;
            value = import (./modules + "/${module}");
          })
          (builtins.attrNames (builtins.readDir ./modules)));

        ## home-manager modules and users
        homeFeatures = system: [
          home-manager.nixosModules.home-manager
          # TODO users should be retrieved from the catalog
          (mkHomeManager [ "root" "jdheyburn" ])
        ];
        # End of modules

        mkUserImports = user: [
          catppuccin.homeManagerModules.catppuccin
          ./home/common
          (./home/users + "/${user}")
        ];

        mkHomeUsers = users: builtins.listToAttrs (map
          (
            user: {
              name = user;
              value = {
                imports = mkUserImports user;
              };
            }
          )
          users
        );

        mkHomeManager = users: {
          # Fixes https://github.com/divnix/digga/issues/30
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.extraSpecialArgs = { inherit system inputs; };
          home-manager.users = mkHomeUsers users;
        };

        # Function to create a nixosSystem
        # TODO any refactoring available with mkDarwinSystem?
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

        mkDarwinSystem = extraModules: users:
          darwin.lib.darwinSystem {
            system = "aarch64-darwin";
            specialArgs = {
              inherit catalog;
              flake-self = self;
            } // inputs;
            modules = [
              home-manager.darwinModules.home-manager
              (mkHomeManager users)
            ] ++ extraModules;
          };

        hosts = builtins.attrNames (builtins.readDir ./hosts);
        darwinNodes = (nixpkgs.lib.attrValues (nixpkgs.lib.filterAttrs (node_name: node_def: node_def ? "isDarwin" && node_def.isDarwin) catalog.nodes));
        nixOSNodes = (nixpkgs.lib.attrValues (nixpkgs.lib.filterAttrs (node_name: node_def: node_def ? "isNixOS" && node_def.isNixOS) catalog.nodes));
      in
      {

        overlays.default = final: prev: (import ./overlays inputs) final prev;

        # home-manager standalone installations
        homeConfigurations = builtins.listToAttrs (map
          (user: {
            name = user;
            value = home-manager.lib.homeManagerConfiguration {
              pkgs = nixpkgs.legacyPackages."x86_64-linux";
              # TODO roles shouldn't be appended here
              modules = (mkUserImports user) ++ [ ./home/roles/desktop ];
            };
            # TODO jdheyburn should not be hardcoded here
          }) [ "jdheyburn" ]);

        darwinConfigurations = builtins.listToAttrs (map
          (node:
            let
              modules = [
                (./hosts + "/${node.hostName}/configuration.nix")
              ];
            in
            {
              name = node.hostName;
              value = mkDarwinSystem modules node.users;
            })
          darwinNodes);

        nixosConfigurations = builtins.listToAttrs (map
          (node:
            let
              modules = [ (./hosts + "/${node.hostName}/configuration.nix") ]
                ++ nixpkgs.lib.optional (node ? "nixosHardware") node.nixosHardware;
            in
            {
              name = node.hostName;
              value = mkLinuxSystem node.system modules;
            })
          nixOSNodes);

        # deploy-rs configs - built off what exists in ./hosts and in catalog.nix
        deploy.nodes = builtins.listToAttrs (map
          (host: {
            name = node.hostName;
            value = {
              hostname = node.ip.tailscale;
              profiles.system = {
                user = "root";
                path = deploy-rs.lib.${node.system}.activate.nixos
                  self.nixosConfigurations.${node.hostName};
                sshOpts = [ "-o" "IdentitiesOnly=yes" ];
              };
            };
          })
          nixOSNodes);

        checks = builtins.mapAttrs
          (system: deployLib: deployLib.deployChecks self.deploy)
          deploy-rs.lib;

        # allows nix fmt
        # TODO repeated context here, can I map over each of them?
        formatter.x86_64-darwin = nixpkgs.legacyPackages.x86_64-darwin.nixpkgs-fmt;
        formatter.x86_64-linux = nixpkgs.legacyPackages.x86_64-linux.nixpkgs-fmt;
        formatter.aarch64-linux = nixpkgs.legacyPackages.aarch64-linux.nixpkgs-fmt;
        formatter.aarch64-darwin = nixpkgs.legacyPackages.aarch64-darwin.nixpkgs-fmt;
      };
}
