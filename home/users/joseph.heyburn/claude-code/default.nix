{ config, ... }:
let
  claudeDir = ".claude";
  claudeHome = "${config.home.homeDirectory}/${claudeDir}";
in
{
  programs.claude-code = {
    enable = true;

    memory.source = ./CLAUDE.md;

    settings = {
      permissions.allow = [ "Bash(find:*)" ];

      statusLine = {
        type = "command";
        command = "bash ${claudeHome}/statusline-command.sh";
      };

      enabledPlugins = {
        "superpowers@claude-plugins-official" = true;
        "gopls-lsp@claude-plugins-official" = true;
        "clangd-lsp@claude-plugins-official" = true;
        "github-skills@platform-claude-skills" = true;
        "ruby-skills@platform-claude-skills" = true;
        "document-skills@anthropic-agent-skills" = true;
        "example-skills@anthropic-agent-skills" = false;
        # "lapdog@lapdog" = true;
      };

      # extraKnownMarketplaces.lapdog.source = {
      #   source = "github";
      #   repo = "DataDog/dd-apm-test-agent";
      # };

      alwaysThinkingEnabled = true;
      effortLevel = "high";
      tui = "fullscreen";
      voice = {
        enabled = true;
        mode = "hold";
      };
      voiceEnabled = true;
      skipWorkflowUsageWarning = true;
      theme = "dark";
    };
  };

  home.file."${claudeDir}/statusline-command.sh" = {
    source = ./statusline-command.sh;
    executable = true;
  };
}
