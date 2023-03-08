{ config, pkgs, ... }:

{

  home.packages = with pkgs; [
    awscli2
    kubernetes-helm
    sops
  ];
}
