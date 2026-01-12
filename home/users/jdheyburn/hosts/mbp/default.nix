{ config, pkgs, ... }: {

  home.packages = with pkgs; [
    discord
  ];

  modules.ssh-client.enable = true;
  modules.vscode.enable = true;
  modules.beets.enable = true;
}
