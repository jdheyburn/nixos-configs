let

  charlie = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILqG/Ii89DgcU1sKi1v1nofbbZW4uhPfjQZ2l/TRe8Xy";

  dee =
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILWCdUOSth7y3Mt5Qu0uI1qav+VerC1s7xC0p6O6L1l5";

  dennis =
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDL0adtqBxktlaeesYq+C0a9Wu2196VGKoC4CA2mnTf0";

  mac = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHSbn8NGbcOm56ZIFfGBteYHErrlZbLAl0agBPPq0ZJO";

  servers = [ charlie dee dennis mac ];

  jdheyburn = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIozTzNnp+KQAwlMUdJuIcvuQmM+Dz5wlB7H15Qx3iZT"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIC0kg1FOtTN0y3Dpigb6OyPiMtvcPHTfWJXLeO6yyzUp jdheyburn@dennis"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIZdFaYhR7tRI5KyV3XG+jWb0CAT86QYdleQZCVBjUSY jdheyburn@paddys.joannet.casa"
  ];
  users = jdheyburn;

  default = servers ++ users;
in
{
  "adguard-password.age".publicKeys = default;
  "aria2-password.age".publicKeys = default;
  "caddy-environment-file.age".publicKeys = default;
  "grafana-admin-password.age".publicKeys = default;
  "healthchecks-secrets-file.age".publicKeys = default;
  "healthchecks-smtp-password.age".publicKeys = default;
  "healthchecks-superuser-password.age".publicKeys = default;
  "minio-root-credentials.age".publicKeys = default;
  "obsidian-environment-file.age".publicKeys = default;
  "paperless-password.age".publicKeys = default;
  "restic-small-files-password.age".publicKeys = default;
  "restic-media-password.age".publicKeys = default;
  "restic-obsidian-password.age".publicKeys = default;
  "rclone.conf.age".publicKeys = default;
  "thanos-objstore-config.age".publicKeys = default;
  "smtp-password.age".publicKeys = default;
  "unifi-poller-password.age".publicKeys = default;
  "victoriametrics-license.age".publicKeys = default;
}

