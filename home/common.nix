{ config, pkgs, lib, ... }: {

  # You can update Home Manager without changing this value. See
  # the Home Manager release notes for a list of state version
  # changes in each release.
  home.stateVersion = "22.05";

  home.packages = with pkgs; [
    bat # cat alternative
  ];

  # Permit non-free software
  nixpkgs.config.allowUnfree = true;

  programs.fzf = {
    enable = true;
    enableZshIntegration = true;
    tmux = { enableShellIntegration = true; };
  };

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;

  programs.git = {
    enable = true;
    userName = "Joseph Heyburn";
    userEmail = "jdheyburn@gmail.com";
    extraConfig = {
      core.pager =
        "${pkgs.diff-so-fancy}/bin/diff-so-fancy | less --tabs=4 -RFX";
      init.defaultBranch = "main";
      pull.rebase = "false";
      push.autoSetupRemote = "true";
      "url \"git@github.com:\"".insteadOf = "https://github.com/";
    };
  };

  programs.gh = {
    enable = true;
    settings = {
      # Aliases allow you to create nicknames for gh commands
      aliases = { co = "pr checkout"; };

      # What editor gh should run when creating issues, pull requests, etc. If blank, will refer to environment.
      editor = "!!null nvim";

      # What protocol to use when performing git operations. Supported values: ssh, https
      git_protocol = "ssh";

      # A pager program to send command output to, e.g. "less". Set the value to "cat" to disable the pager.
      pager = "";

      # When to interactively prompt. This is a global config that cannot be overridden by hostname. Supported values: enabled, disabled
      prompt = "enabled";
    };
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
      { plugin = tmuxPlugins.tmux-fzf; }
    ];
  };

  # Better cd command
  programs.zoxide = {
    enable = true;
    enableZshIntegration = config.programs.zsh.enable;
    options = [ "--cmd cd" ];
  };

  programs.zsh = {
    enable = true;
    enableAutosuggestions = true;
    enableCompletion = true;
    enableSyntaxHighlighting = true;

    history = {
      save = 10000000;
      size = 10000000;
      ignoreDups = false; # I use HIST_IGNORE_ALL_DUPS later on
    };

    shellAliases = {
      awscf = "vi ~/.aws/config";
      cat = "bat";
      cl = "clear";
      cp = "cp -Rv";
      gpm = "git pull origin $(git_main_branch)";
      h = "history";
      kc = "switch";
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
