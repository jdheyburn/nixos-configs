{ config, pkgs, ... }:
let
  # Declare Python packages that should be available in the global python
  # https://nixos.wiki/wiki/Python
  python-packages = ps: with ps; [
    requests
    virtualenv
  ];
in
{

  home.packages = with pkgs; [
    # Installs Python, and the defined packages
    (python311.withPackages python-packages)
  ];
}
