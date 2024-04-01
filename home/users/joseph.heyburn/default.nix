{ config, pkgs, ... }:
let

  terraform_0_14_10 = pkgs.mkTerraform {
    version = "0.14.10";
    hash = "sha256-3Ie19UfYpapBVvSTIFwE6Zm0X61FwMAJ7nio+iFabhc=";
    vendorHash = "sha256-tWrSr6JCS9s+I0T1o3jgZ395u8IBmh73XGrnJidWI7U=";
  };

  terraform_1_5_2 = pkgs.mkTerraform {
    version = "1.5.2";
    hash = "sha256-Ri2nWLjPPBINXyPIQSbnd1L+t7QLgXiTOgqX8Dk/rXg=";
    vendorHash = "sha256-tfCfJj39VP+P4qhJTpEIAi4XB+6VYtVKkV/bTrtnFA0=";
  };

  # TODO should be pulled from overlays but it's not, so redeclaring here
  velero_1_9_5 = pkgs.callPackage ./velero { };
  kubectl_1_25_4 = pkgs.callPackage ./kubectl/kubectl.nix { };
  openlens = pkgs.callPackage ./openlens { };
  sops_3_7_3 = pkgs.callPackage ./sops { };

  # Declare Python packages that should be available in the global python
  # https://nixos.wiki/wiki/Python
  python-packages = ps: with ps; [
    requests
    virtualenv
  ];
in
{

  home.file.".hyper.js" = {
    enable = true;
    source = ./hyper/hyper.js;
  };

  home.packages = with pkgs; [
    awscli2

    discord

    # better find commmand - search for files matching a name
    fd

    jq
    yq
    
    (pkgs.wrapHelm pkgs.kubernetes-helm { plugins = [ pkgs.kubernetes-helmPlugins.helm-secrets ]; })

    kubernetes-helm
    
    # TUI for k8s
    k9s

    kubectl_1_25_4

    # Additional kube switchers in testing
    kubectx
    kubie

    # switch - better kubectl context and namespace switching
    # Seems to be broken though
    kubeswitch

    # data parsing, in testing
    miller

    minikube

    obsidian

    openlens
    
    # Installs Python, and the defined packages
    (python311.withPackages python-packages)

    # Simple DNS client
    q

    # rg - Search for strings in files
    ripgrep
    
    # Secrets management
    sops_3_7_3
    
    terraform_1_5_2
    terraform-docs

    tldr
    
    # Interfacing with Velero on K8s
    velero_1_9_5
  ];

  programs.direnv.enable = true;

  programs.go.enable = true;

  programs.vscode = {
    enable = true;

    # Means I cannot install extensions in vscode GUI, they have to be done via Nix
    # Might not strictly need it, as `"extensions.autoUpdate" = false;` might be all I need
    mutableExtensionsDir = false;

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
      # Material theme
      # {
      #   name = "vsc-material-theme";
      #   publisher = "Equinusocio";
      #   version = "33.7.0";
      #   sha256 = "sha256-qwnu48dPjJN/wlaiwHS4SU3Yn4Y3GuOB1W+QoSjcgKw=";
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

      "python.showStartPage" = false;

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
}
