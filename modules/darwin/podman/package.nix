{ lib
, buildGoModule
, fetchFromGitHub
, gpgme
, pkg-config
}:

buildGoModule rec {
  pname = "podman-mac-net-connect";
  version = "0.1.2";

  src = fetchFromGitHub {
    owner = "jasonmadigan";
    repo = "podman-mac-net-connect";
    rev = "v${version}";
    hash = "sha256-Rm3YsYFD69oxolnpXwU27L2lN83hxXgB1bTwDRGqllo=";
  };

  # Upstream's go.sum lacks entries for some linux-only imports, which fails
  # `go mod vendor`. Downloading modules instead only resolves what the
  # darwin build needs.
  proxyVendor = true;
  vendorHash = "sha256-WhQo+ym0THp13j17hNR+D4RCexyYSLZYkTxe3JY0SEU=";

  # client/ is its own module, built into the setup image that runs in the VM.
  subPackages = [ "." ];

  # The podman bindings link gpgme through cgo, as in upstream's brew formula.
  nativeBuildInputs = [ pkg-config ];
  buildInputs = [ gpgme ];

  # Matches upstream's `make build-go`. The version also picks the tag of the
  # setup image the tunnel runs in the podman VM.
  ldflags = [
    "-s"
    "-w"
    "-X github.com/jasonmadigan/podman-mac-net-connect/version.Version=${version}"
  ];

  meta = with lib; {
    description = "Route macOS traffic to podman container IPs over a WireGuard tunnel";
    homepage = "https://github.com/jasonmadigan/podman-mac-net-connect";
    license = licenses.mit;
    platforms = platforms.darwin;
    mainProgram = "podman-mac-net-connect";
  };
}
