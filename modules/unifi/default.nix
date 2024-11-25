{ config, catalog, pkgs, lib, ... }:

with lib;

let

  cfg = config.modules.unifi;
in
{

  options.modules.unifi = {
    enable = mkEnableOption "Deploy unifi controller";
  };

  config = mkIf cfg.enable {

    services.caddy.virtualHosts."unifi.svc.joannet.casa".extraConfig = ''
      tls {
        dns cloudflare {env.CLOUDFLARE_API_TOKEN}
      }
      reverse_proxy localhost:${toString catalog.services.unifi.port} {
        transport http {
          tls_insecure_skip_verify
        }
      }
    '';

    # If doing a fresh install then you may need to open 8443
    # temporarily before you can close it out again
    networking.firewall.allowedTCPPorts =
      [ config.services.prometheus.exporters.unpoller.port 8443 ];



    #      virtualisation.oci-containers.containers = {
    #      unifi = {
    #        image = "lscr.io/linuxserver/unifi-network-application:${version}";
    #
    #        dependsOn = [
    #          "unifi-db"
    #        ];
    #
    #        autoStart = true;
    #        extraOptions = [
    #          "--runtime=${pkgs.gvisor}/bin/runsc"
    #        #  "--network=unifi"
    #        ];
    #
    #        environment = {
    #          PUID = "1000";
    #          PGID = "1000";
    #          TZ = "Europe/London";
    #          MONGO_USER = "unifi";
    #          MONGO_PASS = cfg.databasePassword;
    #          MONGO_HOST = "unifi-db";
    #          MONGO_PORT = "27017";
    #          MONGO_DBNAME = "unifi";
    #          MEM_LIMIT = "1024";
    #          MEM_STARTUP = "1024";
    #        };
    #
    #        ports = [
    #          "8443:8443"
    #          "3478:3478/udp"
    #          "10001:10001/udp"
    #          "8080:8080"
    #          "8843:8843"
    #          "8880:8880"
    #          "6789:6789"
    #          "5514:5514/udp"
    #        ];
    #
    #        volumes = [
    #          "${cfg.dataDir}/config:/config"
    #        ];
    #      };
    #
    #      unifi-db = {
    #        image = "docker.io/mongo:7.0.11";
    #
    #        autoStart = true;
    #        extraOptions = [
    ##          "--network=unifi"
    #        ];
    #
    #        volumes = [
    #          "${cfg.dataDir}/db:/data/db"
    #          "${mongoInitJS}:/docker-entrypoint-initdb.d/init-mongo.js:ro"
    #        ];
    #      };
    #    };

    age.secrets."unifi-poller-password".file =
      ../../secrets/unifi-poller-password.age;
    age.secrets."unifi-poller-password".owner =
      config.services.prometheus.exporters.unpoller.user;

    services.unifi = {
      enable = true;
      unifiPackage = pkgs.unifi8;
      mongodbPackage = pkgs.mongodb-7_0;
      #maximumJavaHeapSize = 256;
      openFirewall = true;
    };

    services.prometheus.exporters.unpoller = {
      enable = true;
      controllers = [{
        url = "https://unifi.svc.joannet.casa";
        user = "unifipoller";
        pass = config.age.secrets."unifi-poller-password".path;
        save_ids = true;
        save_events = true;
        save_alarms = true;
        save_anomalies = true;
      }];

      # loki = {
      #   url = "https://loki.svc.joannet.casa";
      #   verify_ssl = true;
      # };
    };

    # TODO this causes a recusive loop
    services.restic.backups.small-files = {
      # WorkingDirectory translates to the stateDir
      # https://github.com/NixOS/nixpkgs/blob/7eee17a8a5868ecf596bbb8c8beb527253ea8f4d/nixos/modules/services/networking/unifi.nix#L4
      paths = [
        #"${config.systemd.services.unifi.serviceConfig.WorkingDirectory}/data/backup/autobackup"
        "/var/lib/unifi/data/backup/autobackup"
      ];
    };
  };
}
