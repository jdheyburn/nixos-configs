{ catalog, config, pkgs, lib, utils, ... }:

with lib;

let cfg = config.modules.healthchecks;
in {
  options.modules.healthchecks = {
    enable = mkEnableOption "enable healthchecks.py";
  };

  config = mkIf cfg.enable {

    age.secrets."healthchecks-secrets-file" =
      utils.secrets.mkOwnedSecret "healthchecks-secrets-file" "healthchecks" "healthchecks";

    age.secrets."healthchecks-smtp-password" =
      utils.secrets.mkOwnedSecret "healthchecks-smtp-password" "healthchecks" "healthchecks";

    age.secrets."healthchecks-superuser-password" =
      utils.secrets.mkOwnedSecret "healthchecks-superuser-password" "healthchecks" "healthchecks";

    services.caddy.virtualHosts."healthchecks.${catalog.domain.service}".extraConfig =
      utils.caddy.mkServiceVHost {
        port = catalog.services.healthchecks.port;
        resolvers = false;
      };

    services.healthchecks = {
      enable = true;
      port = catalog.services.healthchecks.port;

      settings = {
        SITE_ROOT = "https://healthchecks.${catalog.domain.service}";
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

    services.restic.backups.small-files = {
      paths = [ config.services.healthchecks.dataDir ];
      exclude = [ "${config.services.healthchecks.dataDir}/static" ];
    };

    # Default was 90s, and when doing a deploy via deploy-rs after a flake update where everything gets stopped and started
    # caused it to timeout due to CPU strain I guess. Extending it solved the problem.
    systemd.services.healthchecks.serviceConfig.TimeoutStartSec = "5m";
    systemd.services.healthchecks.preStart = ''
      ${config.services.healthchecks.package}/opt/healthchecks/manage.py shell < ${config.services.healthchecks.package}/opt/healthchecks/hc/create_superuser.py
    '';
  };
}

