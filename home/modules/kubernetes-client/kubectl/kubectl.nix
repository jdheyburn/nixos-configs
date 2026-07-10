{ kubectl, fetchFromGitHub }:

kubectl.overrideAttrs (_: rec {
  version = "1.33.6";

  src = fetchFromGitHub {
    owner = "kubernetes";
    repo = "kubernetes";
    rev = "v${version}";
    hash = "sha256-ywmaMRtq/HqkHO4CGspL4AYcn4IbFzAzA0xZRmAgCWE=";
  };
})
