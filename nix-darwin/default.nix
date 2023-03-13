{ self, inputs, config, ... }:
{
  # Configuration common to all macOS systems
  flake = {
    darwinModules = {
      myself = {
        home-manager.users."joseph.heyburn" = { pkgs, ... }: {
          imports = [
            self.homeModules.common-darwin
          ];
        };
      };
      macbook.imports = [
        self.darwinModules.home-manager
        self.darwinModules.myself
      ];
    };
  };
}
