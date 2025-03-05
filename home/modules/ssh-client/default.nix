{ config, pkgs, lib, ... }:

with lib;

let
  cfg = config.modules.ssh-client;
  tmuxSettings = {
    RequestTTY = "yes";
    RemoteCommand = "tmux new-session -A -s ssh_tmux";
  };
in {
  options.modules.ssh-client = { enable = mkEnableOption "ssh client"; };

  config = mkIf cfg.enable {
    services.ssh-agent.enable = ! builtins.elem pkgs.system ["aarch64-darwin"];
    
    programs.ssh = {
      enable = true;
      matchBlocks = {
        # TODO be dynamic, don't create session for self
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
          extraOptions = {
            IdentityFile = "~/.ssh/id_ed25519";
          };
        };
      };
    };
  };
}
