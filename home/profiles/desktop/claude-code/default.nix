{ config, inputs, system, ... }:
let
  claudeDir = ".claude";
  claudeHome = "${config.home.homeDirectory}/${claudeDir}";
in
{
  programs.claude-code = {
    enable = true;
    package = inputs.llm-agents.packages.${system}.claude-code;

    context = ./CLAUDE.md;

    settings = {
      permissions.allow = [ "Bash(find:*)" ];

      statusLine = {
        type = "command";
        command = "bash ${claudeHome}/statusline-command.sh";
      };

      enabledPlugins = {
        "superpowers@superpowers-marketplace" = true;
        "gopls-lsp@claude-plugins-official" = true;
        "clangd-lsp@claude-plugins-official" = true;
        "ruby-lsp@claude-plugins-official" = true;
      };

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
