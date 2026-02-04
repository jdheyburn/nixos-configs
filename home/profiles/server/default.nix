{ pkgs, ... }:
{
  programs.zsh.shellAliases = {
    nrs = "sudo nixos-rebuild switch";
    systemctl = "sudo systemctl";
  };
}
