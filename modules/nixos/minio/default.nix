{ catalog, config, pkgs, lib, myUtils, ... }:

with lib;

let
  cfg = config.modules.minio;
  serverPort = catalog.services.minio.port;
  consolePort = catalog.services.minio.consolePort;
in {

  options.modules.minio = {
    enable = mkEnableOption "Deploy MinIO";
    dataDir = mkOption {
      type = types.path;
      default = "/var/lib/minio/data";
    };
  };

  config = mkIf cfg.enable {

    age.secrets."minio-root-credentials".file =
      myUtils.secrets.file "minio-root-credentials";

    services.caddy.virtualHosts."minio.${catalog.domain.service}".extraConfig =
      myUtils.caddy.mkServiceVHost {
        port = serverPort;
        resolvers = false;
      };
    
    services.caddy.virtualHosts."ui.minio.${catalog.domain.service}".extraConfig =
      myUtils.caddy.mkServiceVHost {
        port = consolePort;
        resolvers = false;
      };

    services.minio = {
      enable = true;
      dataDir = [ cfg.dataDir ];
      listenAddress = ":${toString serverPort}";
      consoleAddress = ":${toString consolePort}";
      rootCredentialsFile = config.age.secrets."minio-root-credentials".path;
    };

    systemd.services.minio = {
      environment = {
        MINIO_BROWSER_REDIRECT_URL = "https://ui.minio.${catalog.domain.service}";
        MINIO_SERVER_URL = "https://minio.${catalog.domain.service}";
        MINIO_PROMETHEUS_AUTH_TYPE = "public";
      };

      serviceConfig = {
        Restart = "on-failure";
        RestartSec = "10s";
      };

      unitConfig = {
        StartLimitIntervalSec = "500";
        StartLimitBurst = "5";
      };
    };
    # systemd.services.minio.environment.MINIO_PROMETHEUS_JOB_ID = "minio";
    # systemd.services.minio.environment.MINIO_PROMETHEUS_URL =
    #   "https://prometheus.svc.joannet.casa";
  };
}
