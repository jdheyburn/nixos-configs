{ config, pkgs, ... }:
let

  terraform_1_11_3 = pkgs.mkTerraform {
    version = "1.11.3";
    hash = "sha256-th2VaFlvRKvL0ZEcAGU9eJui+k5dTaPGtLB2u9Q/vxg=";
    vendorHash = "sha256-Tz01h3VITbvyEAfT8sfU7ghHd+vlCBVsMTTQS96jp7c=";
  };

  sops_3_13_1 = pkgs.sops.overrideAttrs (old: {
    version = "3.13.1";
    src = pkgs.fetchFromGitHub {
      owner = "getsops";
      repo = "sops";
      rev = "v3.13.1";
      hash = "sha256-df3CwJv+sROmikvWZbFGB1OrcSL1svuvFr6WJKYWhDc=";
    };
    vendorHash = "sha256-cdaxcNCCHK2Rve96KvmO9lc9gZtgqu6rDeYb2vRvdHw=";
  });
in
{
  imports = [
    ./claude-code
    ./velero
  ];

  home.packages = with pkgs; [
    awscli2

    discord

    # obsidian

    # Secrets management
    sops_3_13_1

    terraform_1_11_3
    terraform-docs
  ];

  programs.direnv.enable = true;

  programs.go.enable = true;
  # Disabled on 2026-07-08: was used to install Claude Code via npm - not managed via that anymore
  # programs.zsh.sessionVariables.NODE_EXTRA_CA_CERTS = "/Users/joseph.heyburn/.node-certs/ZscalerRootCertificate.pem";

  modules.kubernetes-client.enable = true;
  modules.vscode.enable = true;
}
