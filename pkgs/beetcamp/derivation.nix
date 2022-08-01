with import <nixpkgs> { };

with pkgs.python3Packages;

buildPythonPackage rec {
  pname = "beetcamp";
  version = "0.15.1";

  disabled = !isPy3k;

  src = fetchPypi {
    inherit pname version;
    sha256 = "40c9a2ffd8bd3016f7611d424120442f627f56d518a106847dc93f0ead6ad79a";
  };

  checkInputs = [ pytest ];

  meta = {
    homepage = "https://github.com/snejus/beetcamp";
    description = "Bandcamp autotagger plugin for beets";
    #maintainers = with lib.maintainers; [ ];
  };
}

