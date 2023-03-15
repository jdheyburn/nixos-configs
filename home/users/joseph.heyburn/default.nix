{ config, pkgs, ... }:
let

  terraform_0_14_10 = pkgs.mkTerraform {
    version = "0.14.10";
    hash = "sha256-3Ie19UfYpapBVvSTIFwE6Zm0X61FwMAJ7nio+iFabhc=";
    vendorHash = "sha256-tWrSr6JCS9s+I0T1o3jgZ395u8IBmh73XGrnJidWI7U=";
  };

in
{
  home.packages = with pkgs; [
    awscli2
    kubernetes-helm
    python3
    sops
    terraform_0_14_10
  ];

  programs.direnv.enable = true;

  programs.vscode = {
    enable = true;

    # This is a list of extensions I had manually installed
    # I'm not sure what's really needed for what, they're commented out
    # until I then need them
    extensions = with pkgs.vscode-extensions; [

      # Nix language support for Visual Studio Code.
      bbenoist.nix

      # Markdown linting and style checking for Visual Studio Code
      davidanson.vscode-markdownlint

      # View git log, file history, compare branches or commits
      # donjayamanne.githistory

      # Supercharge Git within VS Code — Visualize code authorship at a glance via Git blame annotations and CodeLens, seamlessly navigate and explore Git repositories, gain valuable insights via rich visualizations and powerful comparison commands, and so much more
      # eamodio.gitlens

      # Code formatter using prettier
      esbenp.prettier-vscode

      # A formatter for shell scripts, Dockerfile, gitignore, dotenv, /etc/hosts, jvmoptions, and other file types
      foxundermoon.shell-format

      # Syntax highlting and autocompletion for Terraform
      hashicorp.terraform

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

      # Syntax highlighing, snippet, and language configuration support for Ruby
      # wingrunr21.vscode-ruby
    ];

    globalSnippets = {
      todo = {
        body = [ "$LINE_COMMENT TODO: $0" ];
        description = "Insert a TODO";
        prefix = [ "todo" ];
      };
    };
    userSettings = {
      "[python]"."editor.formatOnType" = true;

      "diffEditor.ignoreTrimWhitespace" = false;

      "editor.accessibilitySupport" = false;
      "editor.formatOnSave" = true;
      "editor.stickyScroll.enabled" = true;

      "explorer.confirmDelete" = false;
      "explorer.confirmDragAndDrop" = false;

      "files.autoSave" = "afterDelay";
      "files.autoSaveDelay" = 1000;

      "materialTheme.accent" = "Teal";

      "python.showStartPage" = false;

      "terminal.integrated.copyOnSeletion" = true;
      "terminal.integrated.enableMultiLinePasteWarning" = false;
      "terminal.integrated.fontFamily" = "'Meslo LG M DZ for Powerline', monospace",
      "terminal.integrated.fontSize" = 12;

      "workbench.colorTheme" = "Material Theme";
      "workbench.iconTheme" = "material-icon-theme";
      "workbench.startupEditor" = "none";
    };
  };
}
