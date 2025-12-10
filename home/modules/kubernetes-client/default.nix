# home-manager configuration for kubernetes tools

{ config, pkgs, lib, ... }:

with lib;

let
  cfg = config.modules.kubernetes-client;
  kubectl_1_25_4 = pkgs.callPackage ./kubectl/kubectl.nix { };
in {
  options.modules.kubernetes-client = { enable = mkEnableOption "Kubernetes client tools"; };

  config = mkIf cfg.enable {
    home.packages = with pkgs; [
      # helm
      kubernetes-helm
      (pkgs.wrapHelm pkgs.kubernetes-helm { plugins = [ pkgs.kubernetes-helmPlugins.helm-secrets ]; })

      kubectl_1_25_4

      # Additional kube switchers in testing
      kubectx
      # kubie

      # switcher - better kubectl context and namespace switching
      # kubeswitch

      minikube
    ];

    programs.k9s = {
      enable = true;
      aliases = {
        p = "pods";
        dp = "deployments";
        dep = "deployments";
        np = "networkpolicies";
        # Namespace must be hardcoded
        redis = "pod redis redis-component=server";
      };
      views = {
        redis = {
          sortColumn = "NAME:asc";
          columns = [
            "NAME"
            "PF"
            "READY"
            "RESTARTS"
            "NODE"
            "AGE"
          ];
        };
      };
      settings = {
        k9s = {
          readOnly = true;
          ui.enableMouse = false;
        };
      };
    };

    programs.zsh = {
      shellAliases = {
        kc = "kubectx";
        kn = "kubens";
      };
      initContent = ''
        # Migrated from initExtra
        ${builtins.readFile ./zsh-initExtra-kubectl_aliases.zsh}
      '';
    };

    home.file.".kube/kubie.yaml" = {
      enable = false;
      source = ./kubie.yaml;
    };
  };
}
