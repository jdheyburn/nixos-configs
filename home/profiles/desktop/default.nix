{ pkgs, ... }:
{
  imports = [
    ./claude-code
  ];

  home.packages = with pkgs; [
    discord
  ];

  modules.vscode.enable = true;
}
