{ catalog, config, pkgs, lib, ... }:

with lib;

let cfg = config.modules.minio;
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
      ../../secrets/minio-root-credentials.age;

    services.caddy.virtualHosts."minio.svc.joannet.casa".extraConfig = ''
      tls {
        dns cloudflare {env.CLOUDFLARE_API_TOKEN}
      }
      reverse_proxy localhost:${toString catalog.services.minio.port}
    '';
    services.caddy.virtualHosts."ui.minio.svc.joannet.casa".extraConfig = ''
      tls {
        dns cloudflare {env.CLOUDFLARE_API_TOKEN}
      }
      reverse_proxy localhost:${toString catalog.services.minio.consolePort}
    '';

    services.minio = {
      enable = true;
      dataDir = [ cfg.dataDir ];
      listenAddress = ":${toString catalog.services.minio.port}";
      consoleAddress = ":${toString catalog.services.minio.consolePort}";
      rootCredentialsFile = config.age.secrets."minio-root-credentials".path;
    };

    systemd.services.minio = {
      environment = {
        MINIO_BROWSER_REDIRECT_URL = "https://ui.minio.svc.joannet.casa";
        MINIO_SERVER_URL = "https://minio.svc.joannet.casa";
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
