# Only being used by home-manager standalone installations, such as 
# jdheyburn on paddys - soon to be deprecated

{ pkgs, ... }:

let
  tmuxSettings = {
    RequestTTY = "yes";
    RemoteCommand = "tmux new-session -A -s ssh_tmux";
  };
in
{
  services.ssh-agent.enable = true;
  programs.ssh = {
    enable = true;
    matchBlocks = {
      # TODO be dynamic 
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
      mac = {
        extraOptions = tmuxSettings;
      };
      mac-no-tmux = {
        hostname = "mac";
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

