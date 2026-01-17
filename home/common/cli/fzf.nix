{ pkgs, ... }: {

  # fuzzy finder
  # better command history lookback
  programs.fzf = {
    enable = true;
    enableZshIntegration = true;
    tmux = {
      enableShellIntegration = true;
      # Overlay tmux pane in window
      shellIntegrationOptions = [ "-p80%,60%" ];
    };

    # Applied to all usages of fzf
    defaultOptions = [
      "--tmux center"
      "--height 40%"
      "--style full"
      "--layout reverse"
      "--border"
    ];

    # Options passed to Ctrl + R
    historyWidgetOptions = [
      # Preview the command history inline
      "--preview 'echo {} | sed \\\"s/^ *\\([0-9|*]\\+\\) *//\\\" | ${pkgs.bat}/bin/bat --plain --language=sh --color=always'"
      "--preview-window down:1:wrap"
       "--sort"
    ];

    # Command passed to Ctrl + T
    # Filtered to show only files that bat is compatible with
    fileWidgetCommand = "fd --type f";

    # Options passed to Ctrl + T
    fileWidgetOptions = [
      # Preview the file content inline
      "--preview '${pkgs.bat}/bin/bat --color=always {}'"
    ];

    # Options passed to Alt + C
    changeDirWidgetOptions = [
      # Preview the directory structure inline
      "--preview '${pkgs.eza}/bin/eza --color=always --icons=always --long --git --tree --level=2 {}'"
    ];
  };

  programs.tmux.plugins = with pkgs; [
    { plugin = tmuxPlugins.tmux-fzf; }
  ];

  # Might be redundant if enableZshIntegration is set
  programs.zsh.oh-my-zsh.plugins = [ "fzf" ];

  programs.zsh.initContent = ''
    # Below might not be needed if enableZshIntegration is set
    # Remove after a while if no issues are found (2026-01-17)
    # if [ -n "$\{commands[fzf-share]\}" ]; then
    #     source "$(fzf-share)/key-bindings.zsh"
    #     source "$(fzf-share)/completion.zsh"
    # fi

    # Use fd (https://github.com/sharkdp/fd) instead of the default find
    # command for listing path candidates.
    # - The first argument to the function ($1) is the base path to start traversal
    # - See the source code (completion.{bash,zsh}) for the details.
    function _fzf_compgen_path() {
        fd --hidden --follow --exclude ".git" . "$1"
    }

    # Use fd to generate the list for directory completion
    function _fzf_compgen_dir() {
        fd --type d --hidden --follow --exclude ".git" . "$1"
    }
  '';

}
