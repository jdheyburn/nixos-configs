{ config, ... }:
let
  claudeDir = ".claude";
  claudeHome = "${config.home.homeDirectory}/${claudeDir}";
in
{
  # Shared settings, plugins and skills come from home/profiles/agent. These
  # are the desktop-only extras: local toolchains, LSPs and terminal UI.
  programs.claude-code = {
    settings = {
      permissions.allow = [
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

      statusLine = {
        type = "command";
        command = "bash ${claudeHome}/statusline-command.sh";
      };

      enabledPlugins = {
        "gopls-lsp@claude-plugins-official" = true;
        "clangd-lsp@claude-plugins-official" = true;
        "ruby-lsp@claude-plugins-official" = true;
        "compound-writing@compound-writing" = true;
      };

      tui = "fullscreen";
      voice = {
        enabled = true;
        mode = "hold";
      };
      voiceEnabled = true;
      theme = "dark";
    };

    skills = {
      # Repo-local skills vendored under ./skills/<name>/SKILL.md.
      kubernetes-operator-design = ./skills/kubernetes-operator-design;
      review-valkey-operator-pr = ./skills/review-valkey-operator-pr;
      release-valkey-operator = ./skills/release-valkey-operator;
      review-round = ./skills/review-round;
    };
  };

  home.file."${claudeDir}/statusline-command.sh" = {
    source = ./statusline-command.sh;
    executable = true;
  };

  # Quick one-shot questions: `ask why is the sky blue?`, or pipe context in
  # with `cmd | ask explain this`. noglob stops `?` and `*` being expanded.
  programs.zsh.initContent = ''
    _claude_query() { claude -p --model sonnet --effort low "$*" }
  '';
  programs.zsh.shellAliases.ask = "noglob _claude_query";
}
