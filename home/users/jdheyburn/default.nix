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
  # TODO username should be inferred from the directory name
  home.username = "jdheyburn";
  # TODO a better way of declaring this
  home.homeDirectory = if builtins.elem pkgs.system [ "aarch64-darwin" ] then "/Users/jdheyburn" else "/home/jdheyburn";

  home.packages = with pkgs; [
    #discord

    # Installs Python, and the defined packages
    (python311.withPackages python-packages)
  ];

  modules.ssh-client.enable = true;
  modules.vscode.enable = true;
}
