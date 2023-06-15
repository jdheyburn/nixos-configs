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

  # Does not install homebrew, follow the install instructions for this: https://brew.sh
  homebrew.enable = true;
  homebrew.brews = [ ];
  homebrew.casks = [
    "1password"
    "alfred"
    "alt-tab"
    "todoist"
    "firefox"
    "hyper"
    # Tiling tool
    "rectangle"
    "sdm"
    "spotify"
    "viscosity"
    "whatsapp"
  ];
  homebrew.taps = [ ];

  system.defaults = {
    dock = {
      autohide = true;
      autohide-delay = 1.0;
      orientation = "left";
    };

    finder = {
      # Always show file extensions
      AppleShowAllExtensions = true;
      # Set finder to List view style
      FXPreferredViewStyle = "Nlsv";
    };

    screencapture.location = "~/screenshots/";
    NSGlobalDomain = {
      # Don't use Natural scroll direction
      "com.apple.swipescrolldirection" = false;
      # Set the speed of the cursor on the trackpad
      "com.apple.trackpad.scaling" = 2.0;
    };

    trackpad = {
      # Enable tap to click
      Clicking = true;
      # Enable tap to drag
      Dragging = true;
    };
  };

  time.timeZone = "Europe/London";
}
