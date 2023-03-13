{ self, inputs, config, ... }:
{
  flake = {
    homeModules = {
      common = {
        # home.stateVersion = "22.11";
        imports = [
          ./common.nix
        ];
      };
      common-linux = {
        imports = [
          self.homeModules.common
        ];
      };
      common-darwin = {
        imports = [
          self.homeModules.common
          ./users/joseph.heyburn
        ];
      };
    };
  };
}
