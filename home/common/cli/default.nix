{ config, pkgs, lib, ... }: {

  # Better cat command
  programs.bat.enable = true;
  programs.zsh.shellGlobalAliases = {
    # If cat is a global alias then we can pipe to bat
    cat = "${pkgs.bat}/bin/bat";
  };

  # fuzzy finder
  # better command history lookback
  programs.fzf = {
    enable = true;
    enableZshIntegration = true;
    tmux = { enableShellIntegration = true; };
  };
  programs.zsh.oh-my-zsh.plugins = [ "fzf" ];

  # snazzy prompt
  programs.starship = {
    enable = true;
    settings = {
      aws.disabled = true;
      format = lib.concatStrings [
        "$all"
      ];
      kubernetes = {
        disabled = false;
      };
      ruby.disabled = true;
      time.disabled = false;
    };
  };

  # Better cd command that let's you type the name of a dir and cd into it
  programs.zoxide = {
    enable = true;
    enableZshIntegration = config.programs.zsh.enable;
    options = [ "--cmd cd" ];
  };
}
