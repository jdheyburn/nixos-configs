{ pkgs, ... }: {

  # fuzzy finder
  # better command history lookback
  programs.fzf = {
    enable = true;
    enableZshIntegration = true;
    tmux.enableShellIntegration = true;
  };

  programs.tmux.plugins = with pkgs; [
    { plugin = tmuxPlugins.tmux-fzf; }
  ];

  programs.zsh.oh-my-zsh.plugins = [ "fzf" ];

  programs.zsh.initContent = ''
    if [ -n "$\{commands[fzf-share]\}" ]; then
        source "$(fzf-share)/key-bindings.zsh"
        source "$(fzf-share)/completion.zsh"
    fi

    # Use fd (https://github.com/sharkdp/fd) instead of the default find
    # command for listing path candidates.
    # - The first argument to the function ($1) is the base path to start traversal
    # - See the source code (completion.{bash,zsh}) for the details.
    function _fzf_compgen_path() {
        ${pkgs.fd}/bin/fd --hidden --follow --exclude ".git" . "$1"
    }

    # Use fd to generate the list for directory completion
    function _fzf_compgen_dir() {
        ${pkgs.fd}/bin/fd --type d --hidden --follow --exclude ".git" . "$1"
    }
  '';

}
