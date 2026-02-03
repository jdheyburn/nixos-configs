{ config, catalog, pkgs, lib, myUtils, ... }:

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

    systemd.tmpfiles.rules = [
      "d ${dataDir} 0770 unifi unifi -"
      "d ${dataDir}/db 0770 unifi unifi -"
    ];

    services.caddy.virtualHosts."unifi.${catalog.domain.service}".extraConfig =
      myUtils.caddy.mkServiceVHost {
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
        8080 # Device inform
        8443 # Web UI
        8843 # HTTPS portal
        8880 # HTTP portal
        6789 # Mobile speedtest
        27017 # MongoDB (for host networking)
      ];

    networking.firewall.allowedUDPPorts = [
      3478 # UDP port used for STUN
      10001 # UDP port used for device discovery
      1900 # UDP port used for Simple Service Discovery Protocol (SSDP)
      5514 # UDP port used for syslog
    ];

    age.secrets."unifi-poller-password".file =
      myUtils.secrets.file "unifi-poller-password";
    age.secrets."unifi-poller-password".owner =
      config.services.prometheus.exporters.unpoller.user;

    services.unifi = {
      enable = false;
      unifiPackage = pkgs.unifi;
      mongodbPackage = pkgs.mongodb-7_0;
      openFirewall = true;
    };

    age.secrets."unifi-environment-file".file = myUtils.secrets.file "unifi-environment-file";
    age.secrets."unifi-db-environment-file".file = myUtils.secrets.file "unifi-db-environment-file";

    virtualisation.oci-containers.containers = {
      unifi = {
        autoStart = true;
        image = "lscr.io/linuxserver/unifi-network-application:${version}";
        volumes = [ "/var/lib/unifi:/config" ];
        # With --network=host, ports are not needed as container uses host networking directly
        # Keeping for documentation of ports used:
        # 8080: Device inform
        # 8443: Web UI (HTTPS)
        # 3478/udp: STUN
        # 10001/udp: Device discovery
        # 1900/udp: SSDP
        # 8843: HTTPS portal
        # 8880: HTTP portal
        # 6789: Mobile speedtest
        # 5514/udp: Syslog

        dependsOn = [ "unifi-db" ];

        environment = {
          TZ = config.time.timeZone;
          PUID = toString config.users.users.unifi.uid;
          PGID = toString config.users.groups.unifi.gid;
          MONGO_USER = "unifi";
          MONGO_HOST = "localhost";
          MONGO_PORT = "27017";
          MONGO_DBNAME = "unifi";
          MONGO_AUTHSOURCE = "admin";
        };

        extraOptions = [ "--network=host" ];

        environmentFiles = [
          config.age.secrets."unifi-environment-file".path
          config.age.secrets."unifi-db-environment-file".path
        ];
      };
      unifi-db = {
        autoStart = true;
        image = "docker.io/mongo:4.4.18";

        # Run as the host's unifi user to match volume ownership
        user = "${toString config.users.users.unifi.uid}:${toString config.users.groups.unifi.gid}";

        # With --network=host, ports are not needed as container uses host networking directly
        # MongoDB listens on 27017

        volumes = [
          "${dataDir}/db:/data/db"
          "${initDbScript}:/docker-entrypoint-initdb.d/init-db.sh:ro"
        ];

        environment = {
          TZ = config.time.timeZone;
          MONGO_INITDB_ROOT_USERNAME = "root";
          MONGO_USER = "unifi";
          MONGO_DBNAME = "unifi";
          MONGO_AUTHSOURCE = "admin";
        };

        extraOptions = [ "--network=host" ];

        # Sets MONGO_INITDB_ROOT_PASSWORD and MONGO_PASS
        environmentFiles = [ config.age.secrets."unifi-db-environment-file".path ];
      };
    };

    services.prometheus.exporters.unpoller = {
      enable = false;
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
