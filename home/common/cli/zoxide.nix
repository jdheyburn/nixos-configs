{ config, lib, ... }: {
  # Better cd command that let's you type the name of a dir and cd into it
  programs.zoxide = {
    enable = true;
    enableZshIntegration = config.programs.zsh.enable;
    options = [ "--cmd cd" ];
  };

  programs.zsh.initContent = lib.mkAfter ''
    # Claude Code spawns a fresh shell per command; chpwd_functions can be cleared between
    # .zshrc init and command execution. Re-register __zoxide_hook if it was lost.
    function cd() {
        if (( ''${+functions[__zoxide_hook]} )) && [[ ''${chpwd_functions[(Ie)__zoxide_hook]:-0} -eq 0 ]]; then
            chpwd_functions+=(__zoxide_hook)
        fi
        __zoxide_z "$@"
    }
  '';
}
