{ config, pkgs, lib, ... }: {

  # TODO explore replacing with nixvim
  # https://nix-community.github.io/nixvim/
  programs.neovim = {
    enable = true;
    viAlias = true;
    vimAlias = true;
    plugins = with pkgs.vimPlugins; [
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
      ${builtins.readFile ./init.lua}
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
    '';
  };

}
