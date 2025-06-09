{ lib, pkgs, ... }: {

  imports = [
    ./work.nix
  ];

  nix.settings.trusted-users = [ "root" "joseph.heyburn" ];

  # TODO this should be pulled from nodes.NODE.users
  users.users."joseph.heyburn" = {
    home = "/Users/joseph.heyburn";
  };
}
