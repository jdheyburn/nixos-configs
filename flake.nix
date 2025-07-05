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

    # darwin.url = "github:nix-darwin/nix-darwin/nix-darwin-25.05";
    darwin.url = "github:nix-darwin/nix-darwin";
    darwin.inputs.nixpkgs.follows = "nixpkgs-unstable";

    deploy-rs.url = "github:serokell/deploy-rs";

    flake-utils.url = "github:numtide/flake-utils";

    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs-unstable";

    nixos-hardware.url = "github:NixOS/nixos-hardware/master";

    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    # nixpkgs-25-05.url = "github:nixos/nixpkgs/release-25.05";

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

        ## Modules under ./modules
        nixosModules = builtins.listToAttrs (map
          (module: {
            name = module;
            value = import (./modules + "/${module}");
          })
          (builtins.attrNames (builtins.readDir ./modules)));

        ## Modules under ./home/modules
        homeModules = builtins.listToAttrs (map
          (module: {
            name = module;
            value = import (./home/modules + "/${module}");
          })
          (builtins.attrNames (builtins.readDir ./home/modules)));

        ## home-manager modules and users
        homeFeatures = hostname: system: users:
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
            (mkHomeManager hostname ((map (user: user.name) users) ++ additionalUsers))
          ];
        # End of modules

        # Creates a list of imports for a given user, and hostname specific configs for the user if they exist
        mkUserImports = user: hostname: 
          let
            baseImports = [
              catppuccin.homeModules.catppuccin
              ./home/common
              # Imports my own home-manager modules
              { imports = builtins.attrValues homeModules; }
              # User specific config
              (./home/users + "/${user}")
            ];
            hostSpecificPath = ./home/users + "/${user}/hosts/${hostname}";
          in
          baseImports ++ (if (builtins.pathExists hostSpecificPath) then [ hostSpecificPath ] else []);

        mkHomeManager = hostname: usernames: {
          # Fixes https://github.com/divnix/digga/issues/30
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.extraSpecialArgs = { inherit system inputs; };
          home-manager.users = builtins.listToAttrs (map
            (
              username: {
                name = username;
                value = {
                  imports = mkUserImports username hostname;
                  home.username = username;
                  # Apparently not required, appears to be managed by nixos
                  #  error: The option `home-manager.users.jdheyburn.home.homeDirectory' has conflicting definition values:
                  #   - In `<unknown-file>': "/foo/baz"
                  #   - In `/nix/store/5cd4f9xx6l75pg2a2jl1c0av4gq9kcf8-source/nixos/common.nix': "/Users/jdheyburn"
                  # home.homeDirectory = if isDarwin system then "/Users/${username}" else "/home/${username}";
                };
              }
            )
            usernames
          );
        };

        # Platform agnostic function for creating a system
        mkSystem = hostname: system: users: extraModules:
          let
            # users is a list of user objects, need to get the first one's name
            primaryUser = builtins.head (builtins.map (user: user.name) users);
            systemManager =
              if (isDarwin system) then
                darwin.lib.darwinSystem
              else
                nixpkgs.lib.nixosSystem;
          in
          systemManager {
            inherit system;
            specialArgs = {
              inherit catalog primaryUser;
              flake-self = self;
            } // inputs;
            modules =
              # Imports home-manager
              (homeFeatures hostname system users)
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
              modules = (mkUserImports user.name);
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
              value = mkSystem node.hostName node.system node.users modules;
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
              value = mkSystem node.hostName node.system node.users modules;
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
