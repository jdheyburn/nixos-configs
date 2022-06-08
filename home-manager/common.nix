{ config, pkgs, ... }: {

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

  programs.tmux = {
    enable = true;
    clock24 = true;
    keyMode = "vi";
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

      plugins = [ "colored-man-pages" "git" "sudo" ];
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
