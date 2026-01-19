{ config, pkgs, ... }: {
  programs.git = {
    enable = true;
    extraConfig = {
      # https://github.com/NixOS/nixpkgs/issues/169193#issuecomment-1103816735
      safe = { directory = "/etc/nixos"; };
    };
  };
}
