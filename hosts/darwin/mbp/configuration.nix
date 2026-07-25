{ lib, pkgs, deploy-rs, ... }: {

  homebrew.casks = [
    "google-chrome"
    "mullvadvpn"
    "steam"
  ];

  environment.systemPackages = with pkgs; [
    rclone
    deploy-rs.packages.${pkgs.stdenv.hostPlatform.system}.default
  ];

  services.tailscale.enable = true;

  modules.window-tiling.enable = true;
}
