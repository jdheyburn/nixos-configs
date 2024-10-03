{ lib, stdenv, undmg, fetchurl }:

stdenv.mkDerivation rec {
  pname = "openlens";
  version = "6.5.2";
  build = "${version}-309";
  appName = "OpenLens";

  sourceRoot = "${appName}.app";

  src = fetchurl {
    # TODO make dynamic x86 vs arm
    url = "https://github.com/MuhammedKalkan/OpenLens/releases/download/v${build}/OpenLens-${build}-arm64.dmg";
    sha256 = "sha256-5N74qq4ANs7yRke82k1iVGEU7mt84jtZAPF0uOxCJgI=";
  };

  buildInputs = [ undmg ];
  installPhase = ''
    mkdir -p "$out/Applications/${appName}.app"
    cp -R . "$out/Applications/${appName}.app"
  '';

  meta = with lib; {
    description = "The Kubernetes IDE";
    homepage = "https://k8slens.dev/";
    license = licenses.lens;
    maintainers = with maintainers; [ jdheyburn ];
    platforms = [ "aarch64-darwin" ];
  };
}
