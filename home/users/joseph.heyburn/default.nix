{ config, pkgs, ... }:
let

  terraform_1_11_3 = pkgs.mkTerraform {
    version = "1.11.3";
    hash = "sha256-th2VaFlvRKvL0ZEcAGU9eJui+k5dTaPGtLB2u9Q/vxg=";
    vendorHash = "sha256-Tz01h3VITbvyEAfT8sfU7ghHd+vlCBVsMTTQS96jp7c=";
  };
in
{
  imports = [
    ./velero
  ];

  home.file.".config/ghostty/config" = {
    enable = true;
    source = ./ghostty/config;
  };

  home.packages = with pkgs; [
    awscli2

    discord

    # obsidian

    # Secrets management
    sops

    terraform_1_11_3
    terraform-docs
  ];

  programs.direnv.enable = true;

  programs.go.enable = true;

  modules.kubernetes-client.enable = true;
  modules.vscode.enable = true;
}
