{ config, pkgs, lib, ... }: {
  # inspo from:
  #  https://gist.github.com/markandrewj/ead05ebc20f3968ec07e
  #  https://www.youtube.com/watch?v=DzNmUNvnB04
  programs.tmux = {
    enable = true;
    baseIndex = 1;
    clock24 = true;
    keyMode = "vi";
    mouse = true;
    prefix = "C-Space";
    terminal = "screen-256color";

    extraConfig = ''
      # Set true colour
      set-option -sa terminal-overrides ",xterm*:Tc"

      # Status line
      ## Disabled while I see about catputtcin theme
      # set -g status-left-length 85
      # set -g status-left " #h | #(curl icanhazip.com) | #(ifconfig eth0 | grep 'inet ' | awk '{print \"eth0 \" $2}') | "

      # Mouse integration
      ## Should be set via cfg.mouse
      # set -g mouse on
      bind -n WheelUpPane if-shell -F -t = "#{mouse_any_flag}" "send-keys -M" "if -Ft= '#{pane_in_mode}' 'send-keys -M' 'select-pane -t=; copy-mode -e; send-keys -M'"
      bind -n WheelDownPane select-pane -t= \; send-keys -M

      # divider color
      set -g pane-border-style fg=green
      set -g pane-active-border-style bg=default,fg=blue

      # Start windows and panes at 1, not 0
      ## Disabled in favour of baseIndex
      # set -g base-index 1
      # set -g pane-base-index 1
      # set-window-option -g pane-base-index 1
      # set-option -g renumber-windows on

      # Open panes in current directory
      bind '"' split-window -v -c "#{pane_current_path}"
      bind % split-window -h -c "#{pane_current_path}"

      # Set zsh to the default-shell
      # set-option -g default-shell zsh # unsure if this is needed for non-macos
      #d# Needed for macOS
      set-option -g default-command zsh
    '';

    plugins = with pkgs; [
      # Disabled as I think its the cause of high IO on CPU
      #     {
      #       plugin = tmuxPlugins.cpu;
      #       extraConfig = ''
      #         set -g status-right-length 100
      #         set -g status-right '#{cpu_bg_color} CPU: #{cpu_icon} #{cpu_percentage} | #{ram_bg_color} RAM: #{ram_icon} #{ram_percentage} | #[bg=green] %a %d %b %H:%M '
      #       '';
      #     }
      {
        plugin = tmuxPlugins.resurrect;
        extraConfig = ''
          # actually restores the session stuff, not just the layout
          set -g @resurrect-capture-pane-contents 'on'
          # continue nvim if stuff was unsaved, I think?
          set -g @resurrect-strategy-nvim 'session'
        '';
      }
      {
        plugin = tmuxPlugins.continuum;
        extraConfig = ''
          set -g @continuum-restore 'on'
        '';
      }
      # Allow vim key bindings to move between panes (ctrl+hjkl), also integrate with neovim
      { plugin = tmuxPlugins.vim-tmux-navigator; }
      # Better text copy / clipboard support
      {
        plugin = tmuxPlugins.yank;
        extraConfig = ''
          # set vi-mode (I think this is independent of `set -g mode vi`)
          set-window-option -g mode-keys vi
          # keybindings
          bind-key -T copy-mode-vi v send-keys -X begin-selection
          bind-key -T copy-mode-vi C-v send-keys -X rectangle-toggle
          bind-key -T copy-mode-vi y send-keys -X copy-selection-and-cancel
        '';
      }
    ];
  };

  programs.zsh.oh-my-zsh.plugins = [ "tmux" ];

  # oh-my-zsh tmux plugin configuration
  # https://github.com/ohmyzsh/ohmyzsh/tree/master/plugins/tmux
  programs.zsh.sessionVariables = {
    ZSH_TMUX_AUTONAME_SESSION = "true"; # Name sessions after current directory (for manual tmux commands)
    ZSH_TMUX_AUTOQUIT = "false";        # Don't exit shell when detaching from tmux
  };

  programs.zsh.initContent = ''
    ${builtins.readFile ./zsh-initContent-tmux.zsh}
  '';
}
