{ config, lib, inputs, system, ... }:
let
  claudeDir = ".claude";
  claudeHome = "${config.home.homeDirectory}/${claudeDir}";

  # mattpocock productivity skills — the skill name matches its directory name.
  mattpocockSkills = [
    "grill-me"
    "grilling"
    "teach"
    "wait-what"
    "writing-for-agents"
  ];
in
{
  programs.claude-code = {
    enable = true;
    package = inputs.llm-agents.packages.${system}.claude-code;

    context = ./CLAUDE.md;

    settings = {
      # Global command allowlist. These are promoted from per-project
      # settings.local.json where they recurred across repos — all read-only
      # or pure-local (inspect / build / format), nothing that mutates remote
      # state or runs arbitrary code.
      permissions.allow = [
        # Shell inspection
        "Bash(find:*)"
        "Bash(grep:*)"
        "Bash(ls:*)"

        # git (read-only)
        "Bash(git status:*)"
        "Bash(git diff:*)"
        "Bash(git show:*)"
        "Bash(git log:*)"

        # gh (read-only)
        "Bash(gh pr view:*)"
        "Bash(gh pr diff:*)"

        # Go (local build / test / format)
        "Bash(go build:*)"
        "Bash(go test:*)"
        "Bash(go vet:*)"
        "Bash(gofmt:*)"

        # Helm (local render / lint)
        "Bash(helm template:*)"
        "Bash(helm lint:*)"
        "Bash(helm unittest:*)"
        "Bash(helm version:*)"

        # Terraform (local, non-mutating)
        "Bash(terraform fmt:*)"
        "Bash(terraform validate:*)"

        # kubectl (read-only)
        "Bash(kubectl get:*)"
      ];

      # Register the official plugin marketplace so enabledPlugins below resolve
      # on a fresh machine without a manual `/plugin marketplace add`. The name
      # `claude-plugins-official` is reserved by Claude Code and *must* use a
      # GitHub source from the `anthropics` org — a nix-store `directory` source
      # is rejected, so this cannot be pinned via a flake input.
      extraKnownMarketplaces.claude-plugins-official.source = {
        source = "github";
        repo = "anthropics/claude-plugins-official";
      };

      # Third-party marketplace for Obsidian skills (kepano/obsidian-skills).
      # Not a reserved name, so a plain GitHub source is accepted.
      extraKnownMarketplaces.obsidian-skills.source = {
        source = "github";
        repo = "kepano/obsidian-skills";
      };

      statusLine = {
        type = "command";
        command = "bash ${claudeHome}/statusline-command.sh";
      };

      enabledPlugins = {
        "superpowers@claude-plugins-official" = true;
        "gopls-lsp@claude-plugins-official" = true;
        "clangd-lsp@claude-plugins-official" = true;
        "ruby-lsp@claude-plugins-official" = true;
        "obsidian@obsidian-skills" = true;
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

    skills = lib.genAttrs mattpocockSkills (
      name: "${inputs.mattpocock-skills}/skills/productivity/${name}"
    );
  };

  home.file."${claudeDir}/statusline-command.sh" = {
    source = ./statusline-command.sh;
    executable = true;
  };
}
