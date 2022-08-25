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

    services.healthchecks = {
      enable = true;
      port = catalog.services.healthchecks.port;

      settings = {
        REGISTRATION_OPEN = true;
        SITE_ROOT = "https://healthchecks.svc.joannet.casa";
        EMAIL_HOST = "smtp.gmail.com";
        EMAIL_PORT = "587";
        EMAIL_HOST_USER = "jdheyburn@gmail.com";
        # EMAIL_HOST_PASSWORD = "REDACTED";
        EMAIL_HOST_PASSWORD_FILE =
          config.age.secrets."healthchecks-smtp-password".path;
        SECRET_KEY_FILE = config.age.secrets."healthchecks-secrets-file".path;
      };
    };
  };
}

