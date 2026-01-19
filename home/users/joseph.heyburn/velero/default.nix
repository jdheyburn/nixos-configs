{ pkgs, ... }:
let
  version = "1.13.0";
  velero = pkgs.velero.overrideAttrs (old: {
    inherit version;
    src = pkgs.fetchFromGitHub {
      owner = "vmware-tanzu";
      repo = "velero";
      rev = "v${version}";
      hash = "sha256-R9iZpib8hoU9EC6B6Kaj2dWDOkb5qFw1UzsxMBClCso=";
    };
    vendorHash = "sha256-Fu4T2VEW5s/KCdgJLk3bf0wIUhKULK6QuNEmL99MUCI=";
    ldflags = [
      "-s" "-w"
      "-X github.com/vmware-tanzu/velero/pkg/buildinfo.Version=v${version}"
      "-X github.com/vmware-tanzu/velero/pkg/buildinfo.ImageRegistry=velero"
      "-X github.com/vmware-tanzu/velero/pkg/buildinfo.GitTreeState=clean"
      "-X github.com/vmware-tanzu/velero/pkg/buildinfo.GitSHA=none"
    ];
  });
in
{
  home.packages = with pkgs; [
    velero
  ];
}
