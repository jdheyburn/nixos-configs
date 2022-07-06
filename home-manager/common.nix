{ config, pkgs, ... }: {

  home.stateVersion = "22.05";

  programs.fzf = {
    enable = true;
    enableZshIntegration = true;
    tmux = { enableShellIntegration = true; };
  };

  programs.neovim = {
    enable = true;
    viAlias = true;
    vimAlias = true;
    plugins = with pkgs.vimPlugins; [
      # gui for undo tree
      gundo-vim
      # Syntax highlighting for nix files
      vim-nix
      # Save vim sessions, used with tmux-resurrect to bring back unsaved session
      vim-obsession
    ];
    extraConfig = ''
      " Remember last position
      if has("autocmd")
        au BufReadPost * if line("'\"") > 1 && line("'\"") <= line("$") | exe "normal! g'\"" | endif
      endif

      lua << EOF
      ${builtins.readFile ./dotfiles/init.lua}
      EOF

      " indent on new line
      set autoindent 
      " indent, but this time be smart
      set smartindent
    '';
  };

  # inspo from https://gist.github.com/markandrewj/ead05ebc20f3968ec07e
  programs.tmux = {
    enable = true;
    clock24 = true;
    keyMode = "vi";
    terminal = "screen-256color";

    extraConfig = ''
      set -g status-left-length 85
      set -g status-left " #h | #(curl icanhazip.com) | #(ifconfig eth0 | grep 'inet ' | awk '{print \"eth0 \" $2}') | "

      set -g mouse on
      bind -n WheelUpPane if-shell -F -t = "#{mouse_any_flag}" "send-keys -M" "if -Ft= '#{pane_in_mode}' 'send-keys -M' 'select-pane -t=; copy-mode -e; send-keys -M'"
      bind -n WheelDownPane select-pane -t= \; send-keys -M

      # divider color
      set -g pane-border-style fg=green
      set -g pane-active-border-style bg=default,fg=blue
    '';

    plugins = with pkgs; [
      {
        plugin = tmuxPlugins.cpu;
        extraConfig = ''
          set -g status-right-length 100
          set -g status-right '#{cpu_bg_color} CPU: #{cpu_icon} #{cpu_percentage} | #{ram_bg_color} RAM: #{ram_icon} #{ram_percentage} | #[bg=green] %a %d %b %H:%M '
        '';
      }
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
      { plugin = tmuxPlugins.tmux-fzf; }
    ];
  };

  programs.zsh = {
    enable = true;
    enableAutosuggestions = true;
    enableCompletion = true;
    enableSyntaxHighlighting = true;

    history = {
      save = 10000000;
      size = 10000000;
      ignoreDups = false; # I use ALL_DUPS later on
    };

    shellAliases = {
      awscf = "vi ~/.aws/config";
      cl = "clear";
      cp = "cp -Rv";
      gpm = "git pull origin $(git_main_branch)";
      h = "history";
      kc = "kubectx";
      kn = "kubens";
      mv = "mv -v";
      nrs = "sudo nixos-rebuild switch";
      venv = "source .venv/bin/activate";
    };

    shellGlobalAliases = { G = "| grep -i "; };

    localVariables = {
      EDITOR = "nvim";
      SUDO_EDITOR = "nvim";
    };

    initExtra = ''
      ${builtins.readFile ./dotfiles/zsh-initExtra-kubectl_aliases.zsh}
      ${builtins.readFile ./dotfiles/zsh-initExtra-functions.zsh}
      ${builtins.readFile ./dotfiles/zsh-initExtra-misc.zsh}
    '';

    oh-my-zsh = {
      enable = true;
      theme = "agnoster";
      plugins =
        [ "ag" "colored-man-pages" "fd" "fzf" "git" "ripgrep" "sudo" "tmux" ];
    };

    prezto = {
      enable = false;
      tmux = {
        autoStartRemote = true;
        defaultSessionName = "joe-test";
      };
    };
  };
}