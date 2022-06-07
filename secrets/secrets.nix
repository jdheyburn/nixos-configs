let
  dee =
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILWCdUOSth7y3Mt5Qu0uI1qav+VerC1s7xC0p6O6L1l5";

  dennis =
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDL0adtqBxktlaeesYq+C0a9Wu2196VGKoC4CA2mnTf0";

  servers = [ dee dennis ];

  jdheyburn = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIozTzNnp+KQAwlMUdJuIcvuQmM+Dz5wlB7H15Qx3iZT"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIC0kg1FOtTN0y3Dpigb6OyPiMtvcPHTfWJXLeO6yyzUp jdheyburn@dennis"
  ];
  users = jdheyburn;
in {
  "caddy-environment-file.age".publicKeys = servers ++ users;
  "restic-small-files-password.age".publicKeys = servers ++ users;
  "restic-media-password.age".publicKeys = servers ++ users;
  "rclone.conf.age".publicKeys = servers ++ users;
  "unifi-poller-password.age".publicKeys = servers ++ users;
}

