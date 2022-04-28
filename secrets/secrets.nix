let
  dee =
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIELgWHUsrtcGcZ2A/IlBTuRtvE5lcL7n6PGIEHEXW81k";

  servers = [
    dee
  ];

  jdheyburn = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIozTzNnp+KQAwlMUdJuIcvuQmM+Dz5wlB7H15Qx3iZT"
  ];
  users = jdheyburn;
in {
  "caddy-environment-file.age".publicKeys = servers ++ users;
}

