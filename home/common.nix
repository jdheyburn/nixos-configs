{ config, pkgs, lib, ... }: {

  # You can update Home Manager without changing this value. See
  # the Home Manager release notes for a list of state version
  # changes in each release.
  home.stateVersion = "22.05";

  home.packages = with pkgs; [
    delta
    diff-so-fancy
    dyff
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

  # This does take over the whole bat/themes directory, whereas I only
  # need the *.tmTheme files from it. For now this does the job.
  home.file.".config/bat/themes".source = pkgs.fetchFromGitHub {
    owner = "catppuccin";
    repo = "bat";
    rev = "ba4d16880d63e656acced2b7d4e034e4a93f74b1";
    sha256 = "sha256-6WVKQErGdaqb++oaXnY3i6/GuH2FhTgK0v4TN4Y0Wbw=";
  };

  programs.git = {
    enable = true;
    userName = "Joseph Heyburn";
    userEmail = "jdheyburn@gmail.com";
    extraConfig = {
      # Configs related to delta as a differ
      blame.pager = "${pkgs.delta}/bin/delta";
      core.pager = "${pkgs.delta}/bin/delta";
      interative.diffFilter = "${pkgs.delta}/bin/delta --color-only --features=interactive";
      delta = {
        # creates links to the git commit in upstream repo
        hyperlinks = true;
        # Not sure if this works as intended: https://dandavison.github.io/delta/tips-and-tricks/using-delta-with-vscode.html
        hyperlinks-file-link-format = "vscode://file/{path}:{line}";
        light = false;
        line-numbers = true;
        # navigate allows skipping to next/previous file with n/N respectively
        navigate = true;
      };
      merge.conflictstyle = "diff3";
      diff.colorMoved = "default";

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

  # TODO explore replacing with nixvim
  # https://nix-community.github.io/nixvim/
  programs.neovim = {
    enable = true;
    viAlias = true;
    vimAlias = true;
    plugins = with pkgs.vimPlugins; [
      # catppuccin theme
      catppuccin-nvim
      # gui for undo tree
      gundo
      # Integration with tmux for ctrl+hjkl keybindings
      tmux-navigator
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

    extraLuaConfig = ''
      local M = {}

      -- integrate with vim keybindings in tmux for moving across windows
      M.general = {
        n = {
          ["<C-h>"] = { "<cmd> TmuxNavigateLeft<CR>", "window left" },
          ["<C-l>"] = { "<cmd> TmuxNavigateRight<CR>", "window right" },
          ["<C-j>"] = { "<cmd> TmuxNavigateDown<CR>", "window down" },
          ["<C-k>"] = { "<cmd> TmuxNavigateUp<CR>", "window up" },
        }
      }

      -- set theme
      require("catppuccin").setup({
        flavour = "macchiato",
      })
      vim.cmd.colorscheme "catppuccin"
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
      # Integration with fzf
      { plugin = tmuxPlugins.tmux-fzf; }
      # Allow vim key bindings to move between panes (ctrl+hjkl), also integrate with neovim
      { plugin = tmuxPlugins.vim-tmux-navigator; }
      # catppuccin theme
      {
        plugin = tmuxPlugins.catppuccin;
        extraConfig = ''
          # Set the theme flavour, defaults to mocha
          set -g @catppuccin_flavour 'macchiato'
        '';
      }
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

  # Better cd command that let's you type the name of a dir and cd into it
  programs.zoxide = {
    enable = true;
    enableZshIntegration = config.programs.zsh.enable;
    options = [ "--cmd cd" ];
  };

  programs.zsh = {
    enable = true;
    autosuggestion.enable = true;
    enableCompletion = true;
    syntaxHighlighting.enable = true;

    history = {
      save = 10000000;
      size = 10000000;
      ignoreDups = false; # I use HIST_IGNORE_ALL_DUPS later on
    };

    shellAliases = {
      awscf = "vi ~/.aws/config";
      cl = "clear";
      cp = "cp -Rv";
      df = "${pkgs.duf}/bin/duf";
      gpm = "git pull origin $(git_main_branch)";
      h = "history";
      kc = "kubectx";
      kn = "kubens";
      ls = "${pkgs.eza}/bin/eza";
      mv = "mv -v";
      nrs = "sudo nixos-rebuild switch";
      venv = "source .venv/bin/activate";
    };

    shellGlobalAliases = {
      # If cat is a global alias then we can pipe to bat easily enough
      cat = "${pkgs.bat}/bin/bat";
      # One character grep
      G = "| grep -i ";
      # Output to yaml then cat it, useful on k8s resources
      YC = "-o yaml | cat";
    };

    # sessionVariables get prefixed with `export`
    # localVariables do not
    sessionVariables = {
      BAT_THEME = "Catppuccin-macchiato";
      DELTA_PAGER = "less --tabs=4 --RAW-CONTROL-CHARS --no-init --quit-if-one-screen";
      EDITOR = "nvim";
      SUDO_EDITOR = "nvim";
    };

    # This is executed before plugins such as oh-my-zsh are called
    initExtraBeforeCompInit = ''
      # Stops escaping URL characters, slow copy-paste, etc.
      DISABLE_MAGIC_FUNCTIONS=true
    '';

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
