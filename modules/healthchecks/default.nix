{ catalog, config, pkgs, lib, ... }:

with lib;

let cfg = config.modules.healthchecks;
in {
  options.modules.healthchecks = {
    enable = mkEnableOption "enable healthchecks.py";
  };

  config = mkIf cfg.enable {

    age.secrets."healthchecks-secrets-file" = {
      file = ../../secrets/healthchecks-secrets-file.age;
      owner = "healthchecks";
      group = "healthchecks";
    };

    age.secrets."healthchecks-smtp-password" = {
      file = ../../secrets/healthchecks-smtp-password.age;
      owner = "healthchecks";
      group = "healthchecks";
    };

    age.secrets."healthchecks-superuser-password" = {
      file = ../../secrets/healthchecks-superuser-password.age;
      owner = "healthchecks";
      group = "healthchecks";
    };

    services.healthchecks = {
      enable = true;
      port = catalog.services.healthchecks.port;

      settings = {
        SITE_ROOT = "https://healthchecks.svc.joannet.casa";
        SUPERUSER_EMAIL = "jdheyburn@gmail.com";
        SUPERUSER_PASSWORD_FILE =
          config.age.secrets."healthchecks-superuser-password".path;
        EMAIL_HOST = "smtp.gmail.com";
        EMAIL_PORT = "587";
        EMAIL_HOST_USER = "jdheyburn@gmail.com";
        EMAIL_HOST_PASSWORD_FILE =
          config.age.secrets."healthchecks-smtp-password".path;
        SECRET_KEY_FILE = config.age.secrets."healthchecks-secrets-file".path;
      };
    };

    # Default was 90s, and when doing a deploy via deploy-rs after a flake update where everything gets stopped and started
    # caused it to timeout due to CPU strain I guess. Extending it solved the problem.
    systemd.services.healthchecks.serviceConfig.TimeoutStartSec = "5m";
    systemd.services.healthchecks.preStart = ''
      ${config.services.healthchecks.package}/opt/healthchecks/manage.py collectstatic --no-input
      ${config.services.healthchecks.package}/opt/healthchecks/manage.py remove_stale_contenttypes --no-input
      ${config.services.healthchecks.package}/opt/healthchecks/manage.py compress
      ${config.services.healthchecks.package}/opt/healthchecks/manage.py shell < ${config.services.healthchecks.package}/opt/healthchecks/hc/create_superuser.py
    '';
  };
}

