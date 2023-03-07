{ pkgs, ... }: {
  environment.systemPackages = [
    # switch - better kubectl context and namespace switching
    pkgs.kubeswitch
  ];

  # Auto upgrade nix package and the daemon service.
  services.nix-daemon.enable = true;
  nix.package = pkgs.nix;

  # Needs to be duplicated here, even though it is defined in home-manager too
  programs.zsh.enable = true;

  # TODO add brews as and when they come
  homebrew.enable = false;
  homebrew.brews = [

  ];
  homebrew.casks = [ ];
  homebrew.taps = [ ];

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
