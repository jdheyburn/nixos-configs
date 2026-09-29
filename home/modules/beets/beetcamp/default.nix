{
  lib,
  python3,
  fetchFromGitHub,
  beets,
}:

# Use buildPythonPackage (not Application) so it integrates as a library
# that beets can discover as a plugin
python3.pkgs.buildPythonPackage rec {
  pname = "beetcamp";
  version = "0.25.0";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "snejus";
    repo = "beetcamp";
    rev = version;
    hash = "sha256-uNt6c009rb5CYERFdryoZKigBK8aE/rC+nsOLCRTFts=";
  };

  build-system = [ python3.pkgs.poetry-core ];

  preBuild = ''
    HOME=$PWD
  '';

  nativeBuildInputs = [ beets ];

  dependencies = with python3.pkgs; [
    httpx
    packaging
    pycountry
  ];

  pythonImportsCheck = [ "beetsplug.bandcamp" ];

  meta = {
    description = "Bandcamp autotagger source for beets (https://beets.io)";
    homepage = "https://github.com/snejus/beetcamp";
    changelog = "https://github.com/snejus/beetcamp/blob/${src.rev}/CHANGELOG.md";
    license = lib.licenses.gpl2Only;
    maintainers = [ ];
  };
}

