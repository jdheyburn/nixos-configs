{ lib, pkgs, primaryUser, config, ... }: {

  # Required in newer nix-darwin
  system.stateVersion = 4;

  # Determinate uses its own daemon to manage the Nix installation that conflicts with nix-darwin's native Nix management
  nix.enable = false;
  nix.package = pkgs.nix;
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nixpkgs.config.allowUnfree = true;

  # Cleanup old files
  nix.gc.automatic = false;
  nix.gc.options = "--delete-older-than 30d";
  nix.optimise.automatic = false;

  system.activationScripts.postActivation = {
    text = ''
      # Show diff after switch - https://gist.github.com/luishfonseca/f183952a77e46ccd6ef7c907ca424517
      # Fresh systems won't have /run/current-system
      if [ -d /run/current-system ]; then
        ${pkgs.nvd}/bin/nvd --nix-bin-dir=${pkgs.nix}/bin diff /run/current-system "$systemConfig"
      fi

      # Activate new macOS settings immediately,
      sudo -u ${config.system.primaryUser} /System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings -u
    '';
  } // lib.optionalAttrs pkgs.stdenv.isLinux {
    supportsDryActivation = true;
  };

  # Needs to be duplicated here, even though it is defined in home-manager too
  programs.zsh.enable = true;

  # Does not install homebrew, follow the install instructions for this: https://brew.sh
  homebrew.enable = true;
  homebrew.brews = [
    "blueutil"
    # Not working for the time being
    # "ghostty"
    "switchaudio-osx"
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
    "vlc"
    "whatsapp"
  ];
  homebrew.taps = [ ];

  # Allow sudo using fingerprint authentication
  security.pam.services.sudo_local.touchIdAuth = true;

  # macos system settings
  system.primaryUser = primaryUser;
  system.defaults = {
    CustomUserPreferences = {
      "com.apple.symbolichotkeys" = {
        AppleSymbolicHotKeys = {
          "60" = {
            # Disable '^ + Space' for selecting the previous input source
            enabled = false;
          };
          "61" = {
            # Disable '^ + Option + Space' for selecting the next input source
            enabled = false;
          };
          # Disable 'Cmd + Space' for Spotlight Search
          "64" = {
            enabled = false;
          };
          # Disable 'Cmd + Alt + Space' for Finder search window
          "65" = {
            # Set to false to disable
            enabled = true;
          };
        };
      };
      NSGlobalDomain = {
        NSUserKeyEquivalents = {
          # Disable Cmd+M minimize shortcut by reassigning it to something harmless
          Minimize = "@~^\\Uf70f";
          Minimise = "@~^\\Uf70f";
        };
      };
    };

    dock = {
      autohide = true;
      autohide-delay = 1.0;
      orientation = "left";

      # Disable hot corners (1 = disabled)
      wvous-tl-corner = 1;
      wvous-bl-corner = 1;
      wvous-tr-corner = 1;
      wvous-br-corner = 1;
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
