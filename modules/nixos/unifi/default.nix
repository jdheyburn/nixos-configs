{ config, catalog, pkgs, lib, utils, ... }:

with lib;

let
  dataDir = "/var/lib/unifi";
  cfg = config.modules.unifi;
  port = catalog.services.unifi.port;
  version = "10.0.162-ls110";
  initDbScript = pkgs.writeShellScript "init-mongo.sh" (builtins.readFile ./init-mongo.sh);
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

    services.caddy.virtualHosts."unifi.${catalog.domain.service}".extraConfig =
      utils.caddy.mkServiceVHost {
        port = port;
        resolvers = false;
        extraProxyConfig = ''
          transport http {
            tls_insecure_skip_verify
          }
        '';
      };

    networking.firewall.allowedTCPPorts =
      [
        config.services.prometheus.exporters.unpoller.port
        config.services.unifi.port
        8443
      ];

    networking.firewall.allowedUDPPorts = [
      3478 # UDP port used for STUN
      10001 # UDP port used for device discovery
      1900 # UDP port used for Simple Service Discovery Protocol (SSDP)
      5514 # UDP port used for syslog
    ];

    age.secrets."unifi-poller-password".file =
      utils.secrets.file "unifi-poller-password";
    age.secrets."unifi-poller-password".owner =
      config.services.prometheus.exporters.unpoller.user;

    services.unifi = {
      enable = false;
      unifiPackage = pkgs.unifi;
      mongodbPackage = pkgs.mongodb-7_0;
      openFirewall = true;
    };

    age.secrets."unifi-environment-file".file = utils.secrets.file "unifi-environment-file";
    age.secrets."unifi-db-environment-file".file = utils.secrets.file "unifi-db-environment-file";

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

        environment = {
          TZ = "Europe/London";
          PUID = config.users.users.unifi.uid;
          PGUID = config.users.users.unifi.gid;
          MONGO_USER = "unifi";
          MONGO_HOST = "unifi-db";
          MONGO_PORT = "27017";
          MONGO_DBNAME = "unifi";
          MONGO_AUTHSOURCE = "admin";
        };

        environmentFiles = [
          config.age.secrets."unifi-environment-file".path
          config.age.secrets."unifi-db-environment-file".path
        ];
      };
      unifi-db = {
        enable = true;
        image = "docker.io/mongo:8.2.2";

        ports = [
          "27017:27017/tcp"
        ];

        volumes = [
          "${dataDir}/db:/data/db"
          "${initDbScript}:/docker-entrypoint-initdb.d/init-db.sh:ro"
        ];

        environment = {
          TZ = "Europe/London";
          PUID = config.users.users.unifi.uid;
          PGUID = config.users.users.unifi.gid;
          MONGO_INITDB_ROOT_USERNAME = "root";
          MONGO_USER = "unifi";
          MONGO_DBNAME = "unifi";
          MONGO_AUTHSOURCE = "admin";
        };

        # Sets MONGO_INITDB_ROOT_PASSWORD and MONGO_PASS
        environmentFiles = [ config.age.secrets."unifi-db-environment-file".path ];
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
