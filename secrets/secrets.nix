let
  deeHost =
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIELgWHUsrtcGcZ2A/IlBTuRtvE5lcL7n6PGIEHEXW81k";
in {
  "caddy-environment-file.age".publicKeys = [ deeHost ];
}
