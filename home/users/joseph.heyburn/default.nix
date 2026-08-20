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
    ./windmill-cli
  ];

  home.packages = with pkgs; [
    # obsidian

    # Secrets management
    sops

    terraform_1_11_3
    terraform-docs
  ];

  programs.direnv.enable = true;

  programs.go.enable = true;
  # Disabled on 2026-07-08: was used to install Claude Code via npm - not managed via that anymore
  # programs.zsh.sessionVariables.NODE_EXTRA_CA_CERTS = "/Users/joseph.heyburn/.node-certs/ZscalerRootCertificate.pem";

  modules.kubernetes-client.enable = true;
}
