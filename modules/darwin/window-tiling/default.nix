{ config, pkgs, lib, ... }:

# Help from: https://www.youtube.com/watch?v=k94qImbFKWE

with lib;

let
  cfg = config.modules.window-tiling;
in
{
  options.modules.window-tiling = {
    enable = mkEnableOption "enable window tiling on macOS";
  };

  config = mkIf cfg.enable {

    environment.systemPackages = with pkgs; [
      skhd
      yabai
    ];

    services.yabai = {
      enable = true;
      config = {
        # focus_follows_mouse = "autoraise";
        mouse_follows_focus = "on";
        window_placement    = "second_child";
        # window_opacity      = "off";
        top_padding         = 5;
        bottom_padding      = 5;
        left_padding        = 5;
        right_padding       = 5;
        window_gap          = 5;
        layout = "bsp";
        mouse_drop_action = "swap";
      };

      extraConfig = ''
        yabai -m rule --add app="^1Password$" manage=off
        yabai -m rule --add app="^Calculator$" manage=off
        yabai -m rule --add app="^System Settings$" manage=off
        yabai -m rule --add app="^TextEdit$" manage=off

        # Fix ghostty windows halving on new tabs
        yabai -m signal --add app='^Ghostty$' event=window_created action='yabai -m space --layout bsp'
        yabai -m signal --add app='^Ghostty$' event=window_destroyed action='yabai -m space --layout bsp'
      '';

      # extraConfig = ''
      #   # Additional yabai configuration
      #   yabai -m config external_bar all:0
      #   yabai -m config window_border on
      #   yabai -m config window_border_color "#ffffff"
      # '';


    };

    services.skhd = {
      enable = true;
      skhdConfig = ''
        # Change window focus within a space
        alt - k : yabai -m window --focus north
        alt - l : yabai -m window --focus east
        alt - j : yabai -m window --focus south
        alt - h : yabai -m window --focus west

        # Change focus between external displays
        alt -s : yabai -m display --focus west
        alt -g : yabai -m display --focus east

        # Modify current layout

        ## Rotate layout clockwise
        shift + alt - r : yabai -m space --rotate 270
        
        ## Flip along y-axis
        shift + alt - y : yabai -m space --mirror y-axis
        
        ## Flip along x-axis
        shift + alt - x : yabai -m space --mirror x-axis
        
        ## Toggle window float
        shift + alt - t : yabai -m window --toggle float --grid 4:4:1:1:2:2

        # Modify window size
        ## Maximise window
        shift + alt - m : yabai -m window --toggle zoom-fullscreen

        ## Balance out tree of windows (resize to occupy same area)
        shift + alt - e : yabai -m space --balance

        # Swap windows
        shift + alt - k : yabai -m window --focus north
        shift + alt - l : yabai -m window --focus east
        shift + alt - j : yabai -m window --focus south
        shift + alt - h : yabai -m window --focus west

        # Move window and split
        ctrl + alt - k : yabai -m window --focus north
        ctrl + alt - l : yabai -m window --focus east
        ctrl + alt - j : yabai -m window --focus south
        ctrl + alt - h : yabai -m window --focus west

        # Move window to display left and right
        shift + alt - s : yabai -m window --display west; yabai -m display --focus west;
        shift + alt - g : yabai -m window --display east; yabai -m display --focus east;

        # Move window to previous and next space
        shift + alt - p : yabai -m window --space prev
        shift + alt - n : yabai -m window --space next

        # Move window to space x
        shift + alt - 1 : yabai -m window --space 1
        shift + alt - 2 : yabai -m window --space 2
        shift + alt - 3 : yabai -m window --space 3
        shift + alt - 4 : yabai -m window --space 4
        shift + alt - 5 : yabai -m window --space 5
        shift + alt - 6 : yabai -m window --space 6
        shift + alt - 7 : yabai -m window --space 7
      '';
    };
  };
}
