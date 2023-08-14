{ pkgs, ... }: {

  imports = [
    ./work.nix
  ];

  # Auto upgrade nix package and the daemon service.
  services.nix-daemon.enable = true;
  nix.package = pkgs.nix;
  nix.settings.trusted-users = [ "root" "joseph.heyburn" ];
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nixpkgs.config.allowUnfree = true;

  # Needs to be duplicated here, even though it is defined in home-manager too
  programs.zsh.enable = true;
  # Dumb hack because something changed causing zsh not to load
  environment.etc.profile.text = ''
if [[ $0 == "/bin/sh" ]]; then
  zsh
fi
'';

  # Does not install homebrew, follow the install instructions for this: https://brew.sh
  homebrew.enable = true;
  homebrew.brews = [
    "blueutil"
  ];
  homebrew.casks = [
    "1password"
    "alt-tab"
    "audacity"
    "firefox"
    "focusrite-control"
    "hyper"
    "logi-options-plus"
    # Spotlight replacement
    # It does a good job of finding Apps installed by Nix
    "raycast"
    # Tiling tool
    "rectangle"
    "spotify"
    "todoist"
    "whatsapp"
  ];
  homebrew.taps = [ ];

  security.pam.enableSudoTouchIdAuth = true;

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

    ".GlobalPreferences"."com.apple.mouse.scaling" = "7.0";

    trackpad = {
      # Enable tap to click
      Clicking = true;
      # Enable tap to drag
      Dragging = true;
    };
  };

  time.timeZone = "Europe/London";

  fonts = {
    fontDir.enable = true;
    fonts = [
      pkgs.meslo-lgs-nf
    ];
  };
}
