{ config, pkgs, ... }:

let
  home-manager = builtins.fetchTarball
    "https://github.com/nix-community/home-manager/archive/master.tar.gz";
in {
  imports = [ (import "${home-manager}/nixos") ];

  home-manager.users.jdheyburn = {

    programs.git = {
      enable = true;
      userName = "Joseph Heyburn";
      userEmail = "jdheyburn@gmail.com";
    };

  };

}

