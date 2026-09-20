{ pkgs, system, inputs, ... }:
let
  # The pinned nixpkgs (used everywhere else) predates todoist-cli's addition
  # to nixpkgs, so pull it from nixpkgs-unstable like the vscode module does.
  pkgsUnstable = import inputs.nixpkgs-unstable { inherit system; };
in
{
  imports = [
    ./claude-code
  ];

  home.packages = with pkgs; [
    discord
  ] ++ [
    pkgsUnstable.todoist-cli
  ];

  modules.vscode.enable = true;
}
