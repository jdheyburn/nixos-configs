{ lib, pkgs, ... }: {

  # nix.linux-builder = {
  #   enable = true;
  #   ephemeral = true;
  #   maxJobs = 4;
  #   config = {
  #     virtualisation = {
  #       darwin-builder = {
  #         diskSize = 40 * 1024;
  #         memorySize = 8 * 1024;
  #       };
  #       cores = 6;
  #     };
  #   };
  # };

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
