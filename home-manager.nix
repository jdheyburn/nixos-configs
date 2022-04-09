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
      };

      shellGlobalAliases = {
        G = "| grep";
      };

      initExtra = builtins.readFile ./dotfiles/zsh-initExtra;

      oh-my-zsh = {
        enable = true;
        theme = "agnoster";

        plugins = [
          "colored-man-pages"
          "git"
          "sudo"
        ];
      };
      
      prezto = {
        enable = false;
        tmux = {
          autoStartRemote = true;
          defaultSessionName = "joe-test";
        };
      };
    };

  };

}

