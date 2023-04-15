{ config, pkgs, ... }:

{
  home.username = "jdheyburn";
  home.homeDirectory = "/home/jdheyburn";

  home.packages = with pkgs; [
    obsidian
  ];
}
