{ pkgs, ... }:
{

  # imports = [ <home-manager/nix-darwin> ];
  # List packages installed in system profile. To search by name, run:
  # $ nix-env -qaP | grep wget
#   environment.systemPackages =
#     [ pkgs.vim
#     ];

  # Auto upgrade nix package and the daemon service.
  services.nix-daemon.enable = true;
  nix.package = pkgs.nix;

  # Needs to be duplicated here, even though it is defined in home-manager too
  programs.zsh.enable = true;

  # TODO add brews as and when they come
  homebrew.enable = false;
  homebrew.brews = [

  ];
  homebrew.casks = [];
  homebrew.taps = [];


  system.defaults = { 
    dock = {
      autohide = true;
      # autohide-delay = 1.0;
      orientation = "left";
    };
    screencapture.location = "~/screenshots/";
  };

  time.timeZone = "Europe/London";
}
