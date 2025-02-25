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
        isDarwin = system: builtins.elem system [ "aarch64-darwin" ];
        isNixOS = system: builtins.elem system [ "x86_64-linux" "aarch64-linux" ];

        inherit (flake-utils.lib) eachSystemMap system;
        catalog = import ./catalog.nix { inherit nixos-hardware; };

        # Modules to import to hosts
        common = [ ./hosts/nixos/common agenix.nixosModules.default ];

        ## Modules under ./modules
        nixosModules = builtins.listToAttrs (map
          (module: {
            name = module;
            value = import (./modules + "/${module}");
          })
          (builtins.attrNames (builtins.readDir ./modules)));

        ## home-manager modules and users
        homeFeatures = system: users:
          let
            homeManager =
              if (isDarwin system) then
                home-manager.darwinModules.home-manager
              else
                home-manager.nixosModules.home-manager;
            # Only create root user on nixOS machines, I might hate this way of declaring it
            additionalUsers = nixpkgs.lib.optional (!isDarwin system) "root";
          in
          [
            homeManager
            (mkHomeManager ((map (user: user.name) users) ++ additionalUsers))
          ];
        # End of modules

        mkUserImports = user: [
          catppuccin.homeManagerModules.catppuccin
          ./home/common
          (./home/users + "/${user}")
        ];

        mkHomeManager = usernames: {
          # Fixes https://github.com/divnix/digga/issues/30
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.extraSpecialArgs = { inherit system inputs; };
          home-manager.users = builtins.listToAttrs (map
            (
              username: {
                name = username;
                value = {
                  imports = mkUserImports username;
                };
              }
            )
            usernames
          );
        };

        # Platform agnostic function for creating a system
        mkSystem = system: users: extraModules:
          let
            systemManager =
              if (isDarwin system) then
                darwin.lib.darwinSystem
              else
                nixpkgs.lib.nixosSystem;
          in
          systemManager {
            inherit system;
            specialArgs = {
              inherit catalog;
              flake-self = self;
            } // inputs;
            modules =
              # Imports home-manager
              (homeFeatures system users)
              ++ extraModules;
          };

        darwinNodes = (nixpkgs.lib.attrValues (nixpkgs.lib.filterAttrs (node_name: node_def: node_def ? "system" && isDarwin node_def.system) catalog.nodes));
        nixOSNodes = (nixpkgs.lib.attrValues (nixpkgs.lib.filterAttrs (node_name: node_def: node_def ? "system" && isNixOS node_def.system) catalog.nodes));
      in
      {

        overlays.default = final: prev: (import ./overlays inputs) final prev;

        # home-manager standalone installations
        homeConfigurations = builtins.listToAttrs (map
          (user: {
            name = user.name;
            value = home-manager.lib.homeManagerConfiguration {
              pkgs = nixpkgs.legacyPackages."x86_64-linux";
              # TODO roles shouldn't be appended here, should be defined similar to modules
              modules = (mkUserImports user.name) ++ [ ./home/roles/desktop ];
            };
          })
          # Currently hardcoded to jdheyburn, for paddys
          [ catalog.users.jdheyburn ]);

        # macOS installations
        darwinConfigurations = builtins.listToAttrs (map
          (node:
            let
              modules = [
                # Top level common that should be applied to all Darwin
                ./hosts/darwin/common
                (./hosts/darwin + "/${node.hostName}/configuration.nix")
              ];
            in
            {
              name = node.hostName;
              value = mkSystem node.system node.users modules;
            })
          darwinNodes);

        # good old NixOS installations
        nixosConfigurations = builtins.listToAttrs (map
          (node:
            let
              modules = [
                  # Top level common that should be applied to all NixOS
                  ./hosts/nixos/common
                  # agenix
                  agenix.nixosModules.default
                  # Imports my own nixOS modules
                  { imports = builtins.attrValues nixosModules; }
                  # Host level configuration
                  (./hosts/nixos + "/${node.hostName}/configuration.nix")
                ] ++ nixpkgs.lib.optional (node ? "nixosHardware") node.nixosHardware;
            in
            {
              name = node.hostName;
              value = mkSystem node.system node.users modules;
            })
          nixOSNodes);

        deploy.nodes = builtins.listToAttrs (map
          (node: {
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
        formatter = builtins.listToAttrs (map
          (system: {
            name = system;
            value = nixpkgs.legacyPackages.${system}.nixpkgs-fmt;
          })
          flake-utils.lib.defaultSystems);
      };
}
