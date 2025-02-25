{ lib, pkgs, ... }: {

  # TODO should be pulled in based from users
  nix.settings.trusted-users = [ "root" "jdheyburn" ];

  # TODO this should be pulled from nodes.NODE.users
  users.users."jdheyburn" = {
    home = "/Users/jdheyburn";
  };

  homebrew.casks = [
    "google-chrome"
    "steam"
  ];

  services.tailscale.enable = true;
}
