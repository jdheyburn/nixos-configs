{ config, pkgs, lib, ... }: {

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
  programs.zsh.oh-my-zsh.plugins = [ "git" ];

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

}
