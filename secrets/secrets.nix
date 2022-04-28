let
  dee =
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIELgWHUsrtcGcZ2A/IlBTuRtvE5lcL7n6PGIEHEXW81k";

  servers = [ dee ];

  jdheyburn = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIozTzNnp+KQAwlMUdJuIcvuQmM+Dz5wlB7H15Qx3iZT"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDL0adtqBxktlaeesYq+C0a9Wu2196VGKoC4CA2mnTf0 jdheyburn@dennis"
  ];
  users = jdheyburn;
in {
  "caddy-environment-file.age".publicKeys = servers ++ users;
  "restic-small-files-password.age".publicKeys = servers ++ users;
  "restic-media-password.age".publicKeys = servers ++ users;
  "rclone.conf.age".publicKeys = servers ++ users;
}

