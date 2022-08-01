{ pkgs ? import <nixpkgs> { } }:

pkgs.stdenv.mkDerivation {
  name = "beet";
  buildInputs =
    [ (pkgs.python39.withPackages (pythonPackages: with pythonPackages; [ ])) ];
  unpackPhase = "true";
  installPhase = ''
    mkdir -p $out/bin
    cp ${./beet.py} $out/bin/beet
    chmod +x $out/bin/beet
  '';
}

