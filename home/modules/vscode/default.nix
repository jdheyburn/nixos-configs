{ config, pkgs, lib, ... }:

with lib;

let
  cfg = config.modules.vscode;
in {
  options.modules.vscode = { enable = mkEnableOption "VSCode"; };

  config = mkIf cfg.enable {
    programs.vscode = {
      enable = true;

      # Means I cannot install extensions in vscode GUI, they have to be done via Nix
      # Might not strictly need it, as `"extensions.autoUpdate" = false;` might be all I need
      mutableExtensionsDir = false;

      profiles.default = {
        # This is a list of extensions I had manually installed
        # I'm not sure what's really needed for what, they're commented out
        # until I then need them
        extensions = with pkgs.vscode-extensions; [

          # Nix language support for Visual Studio Code.
          bbenoist.nix

          # catppuccin theme
          catppuccin.catppuccin-vsc
          catppuccin.catppuccin-vsc-icons

          # Markdown linting and style checking for Visual Studio Code
          davidanson.vscode-markdownlint

          # View git log, file history, compare branches or commits
          # donjayamanne.githistory

          # Supercharge Git within VS Code — Visualize code authorship at a glance via Git blame annotations and CodeLens, seamlessly navigate and explore Git repositories, gain valuable insights via rich visualizations and powerful comparison commands, and so much more
          eamodio.gitlens

          # Code formatter using prettier
          esbenp.prettier-vscode

          # A formatter for shell scripts, Dockerfile, gitignore, dotenv, /etc/hosts, jvmoptions, and other file types
          foxundermoon.shell-format

          # Syntax highlting and autocompletion for Terraform
          hashicorp.terraform

          # Nix language support for Visual Studio Code.
          jnoortheen.nix-ide

          
          github.copilot
          github.copilot-chat

          # Rich Go language support
          golang.go

          # Makes it easy to create, manage, and debug containerized applications.
          ms-azuretools.vscode-docker

          # IntelliSense (Pylance), Linting, Debugging (multi-threaded, remote), Jupyter Notebooks, code formatting, refactoring, unit tests, and more.
          ms-python.python

          # Material Design Icons for Visual Studio Code
          # pkief.material-icon-theme

          # Ruby language support and debugging for Visual Studio Code
          # rebornix.ruby

          # YAML Language Support by Red Hat, with built-in Kubernetes syntax support
          redhat.vscode-yaml

          # Spelling checker for source code
          streetsidesoftware.code-spell-checker

          # Allow remote editing files
          tailscale.vscode-tailscale

          # Syntax highlighing, snippet, and language configuration support for Ruby
          # wingrunr21.vscode-ruby
        ]
        # Install other extension from the marketplace that aren't in nixpkgs
        ++ pkgs.vscode-utils.extensionsFromVscodeMarketplace [
          # AI pair programmer tool that helps you write code faster and smarter.
          # {
          #   name = "copilot";
          #   publisher = "GitHub";
          #   version = "1.338.1652";
          #   sha256 = "sha256-VdyZ6sOAV24XxN0JdbePOI7Tz6nNEgrKxagtiHrpMlI=";
          # }
          # {
          #   name = "copilot-chat";
          #   publisher = "GitHub";
          #   version = "0.29.2025062705";
          #   sha256 = "sha256-jZiv6j3ZhSOnIZTzmVJ7Er90TjfY0SgpS4rcI6Mx/KI=";
          # }
        ];

        globalSnippets = {
          todo = {
            body = [ "$LINE_COMMENT TODO: $0" ];
            description = "Insert a TODO";
            prefix = [ "todo" ];
          };
        };

        keybindings = [
          {
            key = "shift+ctrl+m";
            command = "workbench.action.toggleMaximizedPanel";
          }
          {
            key = "shift+ctrl+t";
            command = "workbench.action.terminal.focus";
          }
        ];

        userSettings = {
          # Theme
          ## Catppuccin
          "workbench.colorTheme" = "Catppuccin Macchiato";
          "workbench.iconTheme" = "catppuccin-macchiato";
          # "catppuccin.accentColor" = "mauve";

          ## Material theme
          # Material theme seems to want to remove this config and to use its own instead
          # "workbench.colorTheme" = "Material Theme Darker";
          # "materialTheme.accent" = "Teal";
          # "workbench.iconTheme" = "material-icon-theme";

          "[json]"."editor.defaultFormatter" = "esbenp.prettier-vscode";

          "[python]"."editor.formatOnType" = true;

          "diffEditor.ignoreTrimWhitespace" = false;

          "editor.accessibilitySupport" = "off";
          "editor.formatOnSave" = true;
          "editor.stickyScroll.enabled" = true;

          "explorer.confirmDelete" = false;
          "explorer.confirmDragAndDrop" = false;

          # Prevent vscode from automatically updating extensions
          # We manage extensions and their versioning in Nix
          "extensions.autoUpdate" = false;

          "files.autoSave" = "afterDelay";
          "files.autoSaveDelay" = 1000;

          # Disable the warning when syncing (git push) via GUI
          "git.confirmSync" = false;

          "github.copilot.selectedCompletionModel" = "gpt-4o-copilot";

          "python.showStartPage" = false;

          "redhat.telemetry.enabled" = false;

          # Disable warning when built-in terminal wants to load files into editor view
          "security.promptForLocalFileProtocolHandling" = false;

          "tailscale.ssh.defaultUsername" = "jdheyburn";

          "terminal.integrated.copyOnSelection" = true;
          # Auto-open zsh in the terminal
          "terminal.integrated.defaultProfile.osx" = "zsh";
          # Required so that zshenv (read: programs.zsh.sessionVariables) get loaded
          # e.g. BAT_THEME, which is used by git differ "delta" for syntax highlighting
          "terminal.integrated.profiles.osx".zsh = {
            path = "zsh";
            args = [ "-l" "-i" ];
          };
          "terminal.integrated.enableMultiLinePasteWarning" = false;
          "terminal.integrated.fontFamily" = "'MesloLGS NF', 'Meslo LG M DZ for Powerline', monospace";
          "terminal.integrated.fontSize" = 12;

          # Disable automatic updates
          "update.mode" = "none";

          # Do not close tabs if you didn't edit them
          "workbench.editor.enablePreview" = false;
          "workbench.startupEditor" = "none";
        };
      };
    };
  };
}
