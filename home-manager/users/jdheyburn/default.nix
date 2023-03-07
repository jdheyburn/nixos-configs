{ config, pkgs, ... }:

{

  programs.git = {
    enable = true;
    userName = "Joseph Heyburn";
    userEmail = "jdheyburn@gmail.com";
    extraConfig = {
      core.pager =
        "${pkgs.diff-so-fancy}/bin/diff-so-fancy | less --tabs=4 -RFX";
      init.defaultBranch = "main";
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
}
