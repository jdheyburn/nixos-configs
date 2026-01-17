{ config, ... }: {
  # Better cd command that let's you type the name of a dir and cd into it
  programs.zoxide = {
    enable = true;
    enableZshIntegration = config.programs.zsh.enable;
    options = [ "--cmd cd" ];
  };

  programs.zsh.initContent = ''
    # Fallback for zoxide's __zoxide_z when running in non-interactive shells
    # (e.g., IDE terminals, AI coding assistants) where zoxide init doesn't run.
    # This gets overwritten by zoxide's real function in interactive shells.
    if ! type __zoxide_z &>/dev/null; then
        function __zoxide_z() {
            builtin cd "$@"
        }
    fi
  '';
}
