{ config, pkgs, lib, ... }: {
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
      ls = "${pkgs.eza}/bin/eza";
      mv = "mv -v";
      nrs = "sudo nixos-rebuild switch";
      venv = "source .venv/bin/activate";
    };

    shellGlobalAliases = {
      # One character grep
      G = "| grep -i ";
      # Output to yaml then cat it, useful on k8s resources
      YC = "-o yaml | cat";
    };

    # sessionVariables get prefixed with `export`
    # localVariables do not
    sessionVariables = {
      DELTA_PAGER = "less --tabs=4 --RAW-CONTROL-CHARS --no-init --quit-if-one-screen";
      EDITOR = "nvim";
      SUDO_EDITOR = "nvim";
    };

    # This is executed before plugins such as oh-my-zsh are called
    initContent = ''
      # Migrated from initExtraBeforeCompInit
      ## Stops escaping URL characters, slow copy-paste, etc.
      DISABLE_MAGIC_FUNCTIONS=true

      # Migrated from initExtra
      ${builtins.readFile ./zsh-initExtra-functions.zsh}
      ${builtins.readFile ./zsh-initExtra-misc.zsh}
    '';

    oh-my-zsh = {
      enable = true;
      plugins =
        [ "colored-man-pages" "sudo" ];
    };
  };
}

