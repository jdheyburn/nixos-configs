{ config, pkgs, ... }: {

  modules.ssh-client.enable = true;
  modules.beets.enable = true;
  modules.musiclib.enable = true;
}
