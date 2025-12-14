{ config, catalog, pkgs, lib, ... }:

with lib;

let
  dataDir = "/var/lib/unifi";
  cfg = config.modules.unifi;
  port = catalog.services.unifi.port;
  version = "10.0.162-ls110";
in
{

  options.modules.unifi = {
    enable = mkEnableOption "Deploy unifi controller";
  };

  config = mkIf cfg.enable {

    users.groups.unifi = { };
    users.users.unifi = {
      group = "unifi";
      isSystemUser = true;
      description = "Unifi controller user";
      home = dataDir;
    };

    services.caddy.virtualHosts."unifi.${catalog.domain.service}".extraConfig = ''
      tls {
        dns cloudflare {env.CLOUDFLARE_API_TOKEN}
      }
      reverse_proxy localhost:${toString port} {
        transport http {
          tls_insecure_skip_verify
        }
      }
    '';

    # If doing a fresh install then you may need to open 8443
    # temporarily before you can close it out again
    networking.firewall.allowedTCPPorts =
      [ config.services.prometheus.exporters.unpoller.port 8443 ];

    age.secrets."unifi-poller-password".file =
      ../../secrets/unifi-poller-password.age;
    age.secrets."unifi-poller-password".owner =
      config.services.prometheus.exporters.unpoller.user;

    services.unifi = {
      enable = false;
      unifiPackage = pkgs.unifi;
      mongodbPackage = pkgs.mongodb-7_0;
      openFirewall = true;
    };

    virtualisation.oci-containers.containers = {
      unifi = {
        enable = false;
        image = "lscr.io/linuxserver/unifi-network-application:${version}";
        volumes = [ "/var/lib/unifi:/config" ];
        ports = [
          "${toString port}:8080"
          "8443:8443/tcp"
          "3478:3478/udp"
          "10001:10001/udp"
          "1900:1900/udp"
          "8843:8843/tcp"
          "8880:8880/tcp"
          "6789:6789/tcp"
          "5514:5514/udp"
        ];

        dependsOn = [ "unifi-db" ];
      };
      unifi-db = {
        enable = true;
        image = "docker.io/mongo:8.2.2";

        ports = [
          "27017:27017/tcp"
        ];

        volumes = [
          "${dataDir}/db:/data/db"
        ];

        environment = {
          TZ = "Europe/London";
          PUID = config.users.users.unifi.uid;
          PGUID = config.users.users.unifi.gid;
          MONGO_INITDB_ROOT_USERNAME = "root";
          MONGO_INITDB_ROOT_PASSWORD = "\${MONGO_INITDB_ROOT_PASSWORD}";
          MONGO_USER = "unifi";
          MONGO_PASS = "\${MONGO_PASS}";
          MONGO_DBNAME = "unifi";
          MONGO_AUTHSOURCE = "admin";
        };
      };
    };

    services.prometheus.exporters.unpoller = {
      enable = true;
      controllers = [{
        url = "https://unifi.${catalog.domain.service}";
        user = "unifipoller";
        pass = config.age.secrets."unifi-poller-password".path;
        save_ids = true;
        save_events = true;
        save_alarms = true;
        save_anomalies = true;
        save_dpi = true;
      }];

      loki = {
        url = "https://loki.${catalog.domain.service}";
        verify_ssl = true;
      };
    };

    services.restic.backups.small-files = {
      # WorkingDirectory translates to the stateDir
      # https://github.com/NixOS/nixpkgs/blob/7eee17a8a5868ecf596bbb8c8beb527253ea8f4d/nixos/modules/services/networking/unifi.nix#L4
      paths = [
        "/var/lib/unifi/data/backup/autobackup"
      ];
    };
  };
}
