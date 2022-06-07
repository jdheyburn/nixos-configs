{ config, pkgs, ... }:

{

  programs.git = {
    enable = true;
    userName = "Joseph Heyburn";
    userEmail = "jdheyburn@gmail.com";
    extraConfig = {
      core = { pager = "${pkgs.diff-so-fancy}/bin/diff-so-fancy | less -RF"; };
    };
  };

  programs.gh = {
    enable = true;
    settings = { git_protocol = "ssh"; };
  };

}

