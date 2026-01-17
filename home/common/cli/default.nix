{ config, pkgs, lib, ... }: {

  imports = [
    ./fzf.nix
    ./zoxide.nix
  ];

  # Better cat command
  programs.bat.enable = true;
  programs.zsh.shellGlobalAliases = {
    # If cat is a global alias then we can pipe to bat
    cat = "${pkgs.bat}/bin/bat";
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
}
