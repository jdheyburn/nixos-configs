{ pkgs, ... }:

let
  tmuxSettings = {
    RequestTTY = "yes";
    RemoteCommand = "tmux new-session -A -s ssh_tmux";
  };
in {
  home.packages = with pkgs; [
    obsidian
  ];

  # SSH client related stuff here, I only want this on paddys (laptop)
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
