{ config, catalog, pkgs, lib, myUtils, ... }:

with lib;

let
  dataDir = "/var/lib/unifi";
  cfg = config.modules.unifi;
  port = catalog.services.unifi.port;
  version = "10.1.85-ls118";
  initDbScript = pkgs.writeShellScript "init-mongo.sh" (builtins.readFile ./init-mongo.sh);
in
{

  options.modules.unifi = {
    enable = mkEnableOption "Deploy unifi controller";
  };

  config = mkIf cfg.enable {

    users.groups.unifi = {
      # Hardcoded to match the gid that it was created with
      gid = 983;
    };
    # TODO should be pulled in from defaultuser (no hardcoding username)
    users.users.jdheyburn.extraGroups = [ "unifi" ];
    users.users.unifi = {
      # Hardcoded to match the uid that it was created with
      uid = 997;
      group = "unifi";
      isSystemUser = true;
      description = "Unifi controller user";
      home = dataDir;
    };

    systemd.tmpfiles.rules = [
      "d ${dataDir} 0770 unifi unifi -"
      "d ${dataDir}/db 0770 unifi unifi -"
    ];

    # Create podman network for unifi containers to communicate
    systemd.services.podman-network-unifi = {
      description = "Create podman network for unifi";
      wantedBy = [ "multi-user.target" ];
      before = [ "podman-unifi-db.service" "podman-unifi.service" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = "${pkgs.podman}/bin/podman network create unifi --ignore";
        ExecStop = "${pkgs.podman}/bin/podman network rm -f unifi";
      };
    };

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

    networking.firewall.allowedTCPPorts = [
      config.services.prometheus.exporters.unpoller.port
      8080 # Device inform
      8443 # Web UI
      8843 # HTTPS portal
      8880 # HTTP portal
      6789 # Mobile speedtest
    ];

    networking.firewall.allowedUDPPorts = [
      3478 # UDP port used for STUN
      10001 # UDP port used for device discovery
      # 1900 (SSDP) removed - conflicts with Plex/UPnP
      5514 # UDP port used for syslog
    ];

    age.secrets."unifi-poller-password".file =
      myUtils.secrets.file "unifi-poller-password";
    age.secrets."unifi-poller-password".owner =
      config.services.prometheus.exporters.unpoller.user;

    age.secrets."unifi-environment-file".file = myUtils.secrets.file "unifi-environment-file";
    age.secrets."unifi-db-environment-file".file = myUtils.secrets.file "unifi-db-environment-file";

    virtualisation.oci-containers.containers = {
      unifi = {
        autoStart = true;
        image = "lscr.io/linuxserver/unifi-network-application:${version}";
        volumes = [ "/var/lib/unifi:/config" ];

        ports = [
          "8080:8080"       # Device inform (MUST be 8080:8080)
          "8443:8443"       # Web UI (HTTPS)
          "3478:3478/udp"   # STUN
          "10001:10001/udp" # Device discovery
          # 1900/udp (SSDP) removed - conflicts with Plex/UPnP, optional anyway
          "8843:8843"       # HTTPS portal
          "8880:8880"       # HTTP portal
          "6789:6789"       # Mobile speedtest
          "5514:5514/udp"   # Syslog
        ];

        dependsOn = [ "unifi-db" ];

        environment = {
          TZ = config.time.timeZone;
          PUID = toString config.users.users.unifi.uid;
          PGID = toString config.users.groups.unifi.gid;
          MONGO_USER = "unifi";
          MONGO_HOST = "unifi-db";
          MONGO_PORT = "27017";
          MONGO_DBNAME = "unifi";
          MONGO_AUTHSOURCE = "admin";
        };

        extraOptions = [ "--network=unifi" ];

        environmentFiles = [
          config.age.secrets."unifi-environment-file".path
          config.age.secrets."unifi-db-environment-file".path
        ];
      };
      unifi-db = {
        autoStart = true;
        # mongo 5.0+ is not supported on Pi 4
        image = "docker.io/mongo:4.4.18";

        # Run as the host's unifi user to match volume ownership
        user = "${toString config.users.users.unifi.uid}:${toString config.users.groups.unifi.gid}";

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

        extraOptions = [ "--network=unifi" ];

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
      paths = [
        "${dataDir}/backup/autobackup"
      ];
    };
  };
}
