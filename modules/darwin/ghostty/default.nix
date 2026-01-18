{ config, pkgs, lib, ... }:

with lib;

let
  cfg = config.modules.ghostty;

  settings = {
      auto-update = "off";

      font-family = "MesloLGS NF";
      font-size = 14;
      macos-titlebar-style = "tabs";
      window-padding-x = 12;
      window-padding-y = 14;
      # Theme is managed by catppuccin-nix
      # theme = "catppuccin-macchiato";

      cursor-style = "block";
      cursor-style-blink = false;
      shell-integration-features = "no-cursor";
      
      copy-on-select = "clipboard";
      
      keybind = [
        "ctrl+alt+shift+o=write_scrollback_file:open"
      ];
  };
in
{
  options.modules.ghostty = {
    enable = mkEnableOption "Ghostty terminal emulator";
  };

  config = mkIf cfg.enable {
    # System-level: Install via Homebrew
    homebrew.casks = [ "ghostty" ];

    # User-level: Configure via home-manager
    home-manager.sharedModules = [
      {
        programs.ghostty = {
          enable = true;
          package = null;  # Null because it is installed via Homebrew
          enableZshIntegration = true;
          settings = settings;
        };
      }
    ];

    # Optional: Configure yabai if window-tiling is enabled
    services.yabai.extraConfig = mkIf config.modules.window-tiling.enable ''
      # Fix ghostty windows halving on new tabs
      yabai -m signal --add app='^Ghostty$' event=window_created action='yabai -m space --layout bsp'
      yabai -m signal --add app='^Ghostty$' event=window_destroyed action='yabai -m space --layout bsp'
    '';
  };
}
