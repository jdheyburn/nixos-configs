{ lib, pkgs, ... }: {

  homebrew.casks = [
    "google-chrome"
    "mullvadvpn"
    "steam"
  ];

  environment.systemPackages = with pkgs; [
    rclone
  ];

  services.tailscale.enable = true;

  modules.window-tiling.enable = true;
}
