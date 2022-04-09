{ config, pkgs, ... }:

let
  home-manager = builtins.fetchTarball
    "https://github.com/nix-community/home-manager/archive/master.tar.gz";
in {
  imports = [ (import "${home-manager}/nixos") ];

  home-manager.users.jdheyburn = {

    programs.git = {
      enable = true;
      userName = "Joseph Heyburn";
      userEmail = "jdheyburn@gmail.com";
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

      localVariables = { EDITOR = "nvim"; };

      initExtra = ''
        ${builtins.readFile ./dotfiles/zsh-initExtra-functions}
        ${builtins.readFile ./dotfiles/zsh-initExtra-misc}
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

    programs.neovim = {
      enable = true;
      viAlias = true;
      vimAlias = true;
      plugins = with pkgs.vimPlugins; [ gundo-vim vim-nix ];
      extraConfig = ''
        " Remember last position
        if has("autocmd")
          au BufReadPost * if line("'\"") > 1 && line("'\"") <= line("$") | exe "normal! g'\"" | endif
        endif

        lua << EOF
        ${builtins.readFile ./dotfiles/init.lua}
        EOF
      '';
    };

    programs.gh = {
      enable = true;
      settings = {
        git_protocol = "ssh";
      };
    };

  };

}

