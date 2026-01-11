# lib/utils/default.nix
{ lib, pkgs, secretsPath }:
rec {
  secrets = rec {
    path = secretsPath;
    file = secretName: path + "/${secretName}.age";
  };
}
