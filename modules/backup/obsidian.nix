{ catalog, config, pkgs, lib, ... }:

with lib;

let
  version = "v1.7.7-ls40";
  dataDir = "/var/lib/obsidian";
  repoDir = "${dataDir}/repo";
  healthcheck = "https://healthchecks.svc.joannet.casa/ping/89c48c0a-3075-460e-a02b-3a325335c488";
  cfg = config.modules.backup.obsidian;
in
{
  options.modules.backup.obsidian = {
    enable = mkEnableOption "Enable Obsidian backups";
    rcloneConfigFile = mkOption { type = types.path; };
    passwordFile = mkOption { type = types.path; };
  };

  config = mkIf cfg.enable {
    services.caddy.virtualHosts."obsidian.svc.joannet.casa".extraConfig = ''
      tls {
        dns cloudflare {env.CLOUDFLARE_API_TOKEN}
        # Below required to get TLS to work on non-local hosts (i.e. charlie)
        resolvers 8.8.8.8
      }
      reverse_proxy localhost:${toString catalog.services.obsidian.port}
    '';

    age.secrets."obsidian-environment-file".file = ../../secrets/obsidian-environment-file.age;

    virtualisation.oci-containers.containers.obsidian = {
      image = "lscr.io/linuxserver/obsidian:${version}";
      volumes = [ "${dataDir}/config:/config" "${repoDir}:/repo" ];
      ports = [ "${toString catalog.services.obsidian.port}:${toString catalog.services.obsidian.port}" ];
      environment = {
        CUSTOM_PORT = toString catalog.services.obsidian.port;
        PUID = "1000";
        PGUID = "100";
        TZ = "Europe/London";
      };
      environmentFiles = [ config.age.secrets."obsidian-environment-file".path ];
      extraOptions = [
        "--network=bridge"
      ];
    };

    age.secrets."restic-obsidian-password".file = ../../secrets/restic-obsidian-password.age;

    services.restic.backups.obsidian = {
      initialize = true;
      repository = "rclone:b2:iifu8Noi-backups/restic/obsidian";
      rcloneConfigFile = cfg.rcloneConfigFile;
      passwordFile = config.age.secrets."restic-obsidian-password".path;
      paths = [ repoDir ];
      timerConfig.OnCalendar = "hourly";
      backupPrepareCommand = ''
        ${pkgs.curl}/bin/curl ${healthcheck}/start

        # Exit if the repo does not exist
        if [[ ! -d ${repoDir} ]]; then
          echo "ERROR: ${repoDir} not found"
          exit 99
        fi

        # Exit if repo size < 50MiB
        if [ $(du -sb ${repoDir} | cut -f1) -lt 52428800 ]; then
          echo "ERROR: ${repoDir} smaller than 50MiB"
          exit 98
        fi
      '';
      backupCleanupCommand = ''
        preStartExitStatus=$(systemctl show restic-backups-obsidian --property=ExecStartPre | grep -oEi 'status=([[:digit:]]+)' | cut -d '=' -f2)
        echo "preStartExitStatus=$preStartExitStatus"
        echo "EXIT_STATUS=$EXIT_STATUS"
        [ $preStartExitStatus -ne 0 ] && returnStatus=$preStartExitStatus || returnStatus=$EXIT_STATUS
        ${pkgs.curl}/bin/curl ${healthcheck}/$returnStatus
      '';
      pruneOpts = [
        "--keep-hourly 72"
        "--keep-daily 90"
        "--keep-weekly 24"
        "--keep-monthly 36"
        "--keep-yearly 10"
      ];
    };
  };
}
