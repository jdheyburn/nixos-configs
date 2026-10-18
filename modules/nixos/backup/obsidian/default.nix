{ catalog, config, pkgs, lib, myUtils, nixpkgs-unstable, ... }:

with lib;

let
  dataDir = "/var/lib/obsidian";
  # restic snapshots repoDir; the vault itself is the folder inside it
  repoDir = "${dataDir}/repo";
  vaultDir = "${repoDir}/Get-Started";
  historyDir = "${dataDir}/history.git";
  healthcheck = "https://healthchecks.${catalog.domain.service}/ping/89c48c0a-3075-460e-a02b-3a325335c488";
  cfg = config.modules.backup.obsidian;

  # obsidian-headless isn't in the pinned nixpkgs release yet. It's unfree, and
  # nixpkgs.config doesn't carry over to a separately-imported instance.
  pkgsUnstable = import nixpkgs-unstable {
    system = pkgs.stdenv.hostPlatform.system;
    config.allowUnfree = true;
  };
  ob = getExe pkgsUnstable.obsidian-headless;

  # Every config category and attachment type, so restic and git see it all
  syncConfigs = "app,appearance,appearance-data,hotkey,core-plugin,core-plugin-data,community-plugin,community-plugin-data";
  syncFileTypes = "image,audio,video,pdf,unsupported";

  scripts = fileset.toSource {
    root = ./.;
    fileset = fileset.unions [ ./vault.py ./history.py ./backfill.py ./mirror.py ./vault-exclude ];
  };
  python = "${pkgs.python3}/bin/python3 -E -s";

  # Attachment targets known to be missing, one per line. Kept on the host
  # because the names come from the vault and this repo is public.
  ignoreFile = "${dataDir}/ignored-missing-attachments";

  obsidian-history = pkgs.writeShellScriptBin "obsidian-history" ''
    export PATH=${makeBinPath [ pkgs.git ]}:$PATH
    exec ${python} ${scripts}/history.py \
      --vault ${vaultDir} \
      --git-dir ${historyDir} \
      --exclude-file ${scripts}/vault-exclude \
      --ignore-file ${ignoreFile} \
      --healthcheck ${toString cfg.missingAttachmentsHealthcheck} \
      "$@"
  '';

  obsidian-sync-check = pkgs.writeShellScriptBin "obsidian-sync-check" ''
    exec ${python} ${scripts}/mirror.py \
      --state-dir ${dataDir}/.config/obsidian-headless/sync \
      --healthcheck ${toString cfg.staleMirrorHealthcheck} \
      "$@"
  '';

  # Run once by hand as root: sudo obsidian-backfill
  obsidian-backfill = pkgs.writeShellScriptBin "obsidian-backfill" ''
    export PATH=${makeBinPath [ pkgs.git ]}:/run/current-system/sw/bin:$PATH
    exec ${python} ${scripts}/backfill.py \
      --restic restic-obsidian \
      --snapshot-path ${repoDir} \
      --restore-path ${vaultDir} \
      --git-dir ${historyDir} \
      --scratch ${dataDir}/backfill \
      --exclude-file ${scripts}/vault-exclude \
      --vault ${vaultDir} \
      --report ${dataDir}/backfill-lost-files.tsv \
      "$@"
  '';
in
{
  options.modules.backup.obsidian = {
    enable = mkEnableOption "Mirror the Obsidian vault with obsidian-headless and back it up";
    rcloneConfigFile = mkOption { type = types.path; };

    history.enable = mkEnableOption "hourly git history of the vault; enable after running obsidian-backfill";

    missingAttachmentsHealthcheck = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Healthchecks ping URL for the missing-attachment check.";
    };

    staleMirrorHealthcheck = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Healthchecks ping URL, failed when the mirror hasn't synced for 15 minutes.";
    };
  };

  config = mkIf cfg.enable {
    assertions = [{
      assertion = cfg.history.enable -> cfg.missingAttachmentsHealthcheck != null;
      message = "modules.backup.obsidian.history.enable needs missingAttachmentsHealthcheck";
    }];

    users.users.obsidian = {
      isSystemUser = true;
      group = "obsidian";
      home = dataDir;
    };
    users.groups.obsidian = { };
    users.users.jdheyburn.extraGroups = [ "obsidian" ];

    systemd.tmpfiles.rules = [
      "d ${dataDir} 0750 obsidian obsidian -"
      "d ${repoDir} 0750 obsidian obsidian -"
      "d ${vaultDir} 0750 obsidian obsidian -"
      # The old container wrote the vault as uid 1000
      "Z ${repoDir} - obsidian obsidian -"
    ];

    # Lets jdheyburn clone the history over SSH from a repo owned by obsidian
    programs.git = {
      enable = true;
      config.safe.directory = [ historyDir ];
    };

    # ob is needed by hand for login, sync-setup and sync-status
    environment.systemPackages = [ pkgsUnstable.obsidian-headless obsidian-backfill ]
      ++ optional cfg.history.enable obsidian-history;

    systemd.services.obsidian-sync = {
      description = "Obsidian Sync mirror (obsidian-headless)";
      wantedBy = [ "multi-user.target" ];
      wants = [ "network-online.target" ];
      after = [ "network-online.target" ];
      # Keeps retrying until the one-off `ob login` and `ob sync-setup`
      startLimitIntervalSec = 0;
      environment.HOME = dataDir;
      serviceConfig = {
        User = "obsidian";
        Group = "obsidian";
        WorkingDirectory = vaultDir;
        ExecStartPre = "${ob} sync-config --path ${vaultDir} --mode mirror-remote --configs ${syncConfigs} --file-types ${syncFileTypes}";
        ExecStart = "${ob} sync --continuous --path ${vaultDir}";
        Restart = "always";
        RestartSec = 60;
      };
    };

    systemd.services.obsidian-history = mkIf cfg.history.enable {
      description = "Commit Obsidian vault history and check for missing attachments";
      wants = [ "network-online.target" ];
      after = [ "network-online.target" ];
      environment.HOME = dataDir;
      serviceConfig = {
        Type = "oneshot";
        User = "obsidian";
        Group = "obsidian";
        UMask = "0027";
        ExecStart = getExe obsidian-history;
      };
    };

    systemd.services.obsidian-sync-check = mkIf (cfg.staleMirrorHealthcheck != null) {
      description = "Alert when the Obsidian Sync mirror goes stale";
      wants = [ "network-online.target" ];
      after = [ "network-online.target" ];
      serviceConfig = {
        Type = "oneshot";
        User = "obsidian";
        Group = "obsidian";
        ExecStart = getExe obsidian-sync-check;
      };
    };

    systemd.timers.obsidian-sync-check = mkIf (cfg.staleMirrorHealthcheck != null) {
      wantedBy = [ "timers.target" ];
      timerConfig.OnCalendar = "*:0/10";
    };

    # Five minutes before restic's hourly run, so each snapshot has the latest commit
    systemd.timers.obsidian-history = mkIf cfg.history.enable {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "*-*-* *:55:00";
        Persistent = true;
      };
    };

    age.secrets."restic-obsidian-password".file = myUtils.secrets.file "restic-obsidian-password";

    services.restic.backups.obsidian = {
      initialize = true;
      repository = "rclone:b2:iifu8Noi-backups/restic/obsidian";
      rcloneConfigFile = cfg.rcloneConfigFile;
      passwordFile = config.age.secrets."restic-obsidian-password".path;
      paths = [ repoDir historyDir ];
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
