{ pkgs, ... }: {
  environment.systemPackages = [
    # switch - better kubectl context and namespace switching
    pkgs.kubeswitch
  ];

  # Auto upgrade nix package and the daemon service.
  services.nix-daemon.enable = true;
  nix.package = pkgs.nix;
  nix.settings.trusted-users = [ "root" "joseph.heyburn" ];
  nixpkgs.config.allowUnfree = true;

  # Needs to be duplicated here, even though it is defined in home-manager too
  programs.zsh.enable = true;

  homebrew.enable = true;
  homebrew.brews = [ ];
  homebrew.casks = [ "wireshark" ];
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
