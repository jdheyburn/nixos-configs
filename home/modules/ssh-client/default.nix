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
    services.ssh-agent.enable = ! builtins.elem pkgs.stdenv.hostPlatform.system ["aarch64-darwin"];
    
    programs.ssh = {
      enable = true;
      enableDefaultConfig = false;
      settings = {
        # TODO be dynamic, don't create session for self
        charlie = tmuxSettings;
        charlie-no-tmux = {
          HostName = "charlie";
        };
        dee = tmuxSettings;
        dee-no-tmux = {
          HostName = "dee";
        };
        dennis = tmuxSettings;
        dennis-no-tmux = {
          HostName = "dennis";
        };
        mac = tmuxSettings;
        mac-no-tmux = {
          HostName = "mac";
        };
        "gitlab.com" = {
          User = "git";
        };
        "github.com" = {
          User = "git";
          IdentityFile = "~/.ssh/id_ed25519";
        };
      };
    };
  };
}
