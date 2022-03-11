{

  nix.nixPath = [
    "nixpkgs=/home/jdheyburn/code/nixpkgs-jdheyburn"
    #"nixpkgs=/home/jdheyburn/code/nixpkgs-nixos-unstable"
    "nixos-config=/etc/nixos/configuration.nix"
    "/nix/var/nix/profiles/per-user/root/channels"
  ];


  imports =
    [ ./common.nix ./host/configuration.nix ./host/hardware-configuration.nix ];
}
