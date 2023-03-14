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
    python310
    sops
    terraform_0_14_10
  ];

  programs.direnv.enable = true;
}
