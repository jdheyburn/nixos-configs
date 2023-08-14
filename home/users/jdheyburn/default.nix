{ config, pkgs, ... }:

let
  tmuxSettings = {
    RequestTTY = "yes";
    RemoteCommand = "tmux new-session -A -s ssh_tmux";
  };
in {
  home.username = "jdheyburn";
  home.homeDirectory = "/home/jdheyburn";

  home.packages = with pkgs; [
    obsidian
  ];

  services.ssh-agent.enable = true;

  programs.ssh = {
      enable = true;
      matchBlocks = {
        charlie = {
          extraOptions = tmuxSettings;
        };
        charlie-no-tmux = {
          hostname = "charlie";
        };
        dee = {
          extraOptions = tmuxSettings;
        };
        dee-no-tmux = {
          hostname = "dee";
        };
        dennis = {
          extraOptions = tmuxSettings;
        };
        dennis-no-tmux = {
          hostname = "dennis";
        };
        "gitlab.com" = {
          user = "git";
        };
        "github.com" = {
          user = "git";
        };
      };
    };
}
