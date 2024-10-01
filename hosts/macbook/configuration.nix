{ lib, pkgs, ... }: {

  imports = [
    ./work.nix
  ];

  # Required in newer nix-darwin
  system.stateVersion = 4;
  # The default Nix build user ID range has been adjusted for
  # compatibility with macOS Sequoia 15. Your _nixbld1 user currently has
  # UID 301 rather than the new default of 351.

  # You can automatically migrate the users with the following command:

  #     curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- repair sequoia --move-existing-users

  # If you have no intention of upgrading to macOS Sequoia 15, or already
  # have a custom UID range that you know is compatible with Sequoia, you
  # can disable this check by setting:
  ids.uids.nixbld = 300;

  # Auto upgrade nix package and the daemon service.
  services.nix-daemon.enable = true;
  nix.package = pkgs.nix;
  nix.settings.trusted-users = [ "root" "joseph.heyburn" ];
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nixpkgs.config.allowUnfree = true;

  # Cleanup old files
  nix.gc.automatic = true;
  nix.gc.options = "--delete-older-than 30d";
  nix.settings.auto-optimise-store = true;

  # Show diff after switch - https://gist.github.com/luishfonseca/f183952a77e46ccd6ef7c907ca424517
  system.activationScripts.postUserActivation = {
    text = ''
      ${pkgs.nvd}/bin/nvd --nix-bin-dir=${pkgs.nix}/bin diff /run/current-system "$systemConfig"
    '';
  } // lib.optionalAttrs pkgs.stdenv.isLinux {
    supportsDryActivation = true;
  };

  # Needs to be duplicated here, even though it is defined in home-manager too
  programs.zsh.enable = true;

  # Dumb hack because something changed causing zsh not to load
  # 2023-08-24 I believe I fixed this by having zsh as a profile in hyper.js
#   environment.etc.profile.text = ''
# if [[ $0 == "/bin/sh" ]]; then
#   zsh
# fi
# '';

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
    "steam"
    "todoist"
    "vlc"
    "whatsapp"
  ];
  homebrew.taps = [ ];

  # Allow sudo using fingerprint authentication
  security.pam.enableSudoTouchIdAuth = true;

  # macos system settings
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

    ".GlobalPreferences"."com.apple.mouse.scaling" = 7.0;

    trackpad = {
      # Enable tap to click
      Clicking = true;
      # Enable tap to drag
      Dragging = true;
    };
  };

  time.timeZone = "Europe/London";

  fonts = {
    packages = [
      pkgs.meslo-lgs-nf
    ];
  };
}
