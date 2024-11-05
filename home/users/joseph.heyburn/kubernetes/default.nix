# home-manager configuration for kubernetes tools

{ config, pkgs, ... }:
let
  kubectl_1_25_4 = pkgs.callPackage ./kubectl/kubectl.nix { };
in
{
  home.packages = with pkgs; [

    # helm
    kubernetes-helm
    (pkgs.wrapHelm pkgs.kubernetes-helm { plugins = [ pkgs.kubernetes-helmPlugins.helm-secrets ]; })

    kubectl_1_25_4

    # Additional kube switchers in testing
    kubectx
    kubie

    # switcher - better kubectl context and namespace switching
    # kubeswitch

    minikube
  ];

  programs.k9s = {
    enable = true;
    aliases.aliases = {
      p = "pods";
      dp = "deployments";
      dep = "deployments";
      np = "networkpolicies";
    };
    settings = {
      k9s = {
        ui.enableMouse = true;
      };
    };
  };

  programs.zsh = {
    shellAliases = {
      kc = "kubie ctx";
      kn = "kubie ns";
    };
    initExtra = ''
      ${builtins.readFile ./zsh-initExtra-kubectl_aliases.zsh}
    '';
  };



  home.file.".kube/kubie.yaml" = {
    enable = true;
    source = ./kubie.yaml;
  };
}
