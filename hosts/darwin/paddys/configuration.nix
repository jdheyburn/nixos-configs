{ lib, pkgs, ... }: {

  # Matches the flake attribute, so `darwin-rebuild --flake .` finds this config.
  networking.hostName = "paddys";
  networking.localHostName = "paddys";
  networking.computerName = "paddys";

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
