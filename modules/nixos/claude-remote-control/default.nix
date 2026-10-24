{ config, pkgs, lib, utils, llm-agents, ... }:

# Always-on Claude Code Remote Control server, steerable from claude.ai/code
# and the Claude app. Three layers keep it from breaking the host:
#
#   1. A dedicated `claude` system user: no wheel, no SSH keys to other
#      nodes, no deploy-rs access. Worst case it trashes its own home.
#   2. systemd hardening: the OS is read-only apart from that home, other
#      users' homes are hidden, and memory/CPU are capped.
#   3. Claude Code's own sandbox (bubblewrap + socat) around every shell
#      command, enforced from managed settings so a repo can't loosen it.
#
# One-time manual steps after the first deploy (they can't be declarative:
# Remote Control rejects setup-token and API-key auth, and the trust prompt
# needs a terminal):
#
#   sudo -u claude -i claude auth login        # choose the claude.ai option
#   sudo -u claude -i sh -c 'cd ~/code && claude remote-control'
#                                              # answer y, then Ctrl-C
#   sudo systemctl restart claude-remote-control

with lib;

let
  cfg = config.modules.claude-remote-control;
  home = cfg.stateDir;

  # Enforced via /etc/claude-code/managed-settings.d, which sits above user,
  # project and --settings values. Disabling the unsandboxed retry there
  # makes the sandbox "admin-required", so a cloned repo's
  # .claude/settings.json can't add excludedCommands or domains.
  managedSettings = {
    sandbox = {
      enabled = true;
      # Refuse to start rather than silently run commands unsandboxed.
      failIfUnavailable = true;
      # No dangerouslyDisableSandbox retries.
      allowUnsandboxedCommands = false;
      # Inside an outer container bubblewrap can't mount a fresh /proc, so
      # it reuses the existing one. Only for when something else is the
      # real boundary (see modules/nixos/claude-container).
      enableWeakerNestedSandbox = cfg.sandbox.weakerNested;
      enableWeakerNetworkIsolation = false;

      network = {
        allowedDomains = cfg.sandbox.allowedDomains;
        # Unknown hosts are denied rather than prompting on your phone.
        strictAllowlist = true;
        allowManagedDomainsOnly = true;
        allowAllUnixSockets = false;
        allowLocalBinding = false;
        # So `nix build` and friends can reach the daemon. Note the daemon
        # fetches on Claude's behalf outside the sandbox (e.g. fetchurl);
        # drop this if you'd rather Claude couldn't use nix at all.
        allowUnixSockets = optional cfg.sandbox.allowNixDaemon
          "/nix/var/nix/daemon-socket/socket";
      };

      # Claude's own login is a full-scope token: keep it away from the
      # commands Claude runs.
      credentials.files = map (path: { inherit path; mode = "deny"; }) [
        "~/.claude/.credentials.json"
        "~/.config/gh"
        "~/.ssh"
      ];
    };

    permissions = {
      # The file tools sit outside the bash sandbox, so deny them separately.
      deny = [
        "Read(~/.claude/.credentials.json)"
        "Edit(~/.claude/.credentials.json)"
        "Read(~/.config/gh/**)"
      ];
      disableBypassPermissionsMode = "disable";
    };
  };
in
{

  options.modules.claude-remote-control = {
    enable = mkEnableOption "an always-on Claude Code Remote Control server, reachable from claude.ai/code and the Claude app";

    package = mkOption {
      type = types.package;
      default = llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.claude-code;
      description = "Claude Code package to run. Same source as the desktop profile.";
    };

    user = mkOption {
      type = types.str;
      default = "claude";
      description = ''
        Dedicated system user the server runs as. It is created by this
        module, isn't in wheel and has no SSH keys, so a bad command can't
        sudo or hop to other nodes.
      '';
    };

    uid = mkOption {
      type = types.nullOr types.int;
      default = null;
      description = "Fixed UID for the user. Leave null to let NixOS allocate one.";
    };

    stateDir = mkOption {
      type = types.str;
      default = "/var/lib/claude-remote-control";
      description = "Home of the user: login, trust and repos live here. The only writable path.";
    };

    directory = mkOption {
      type = types.str;
      default = "${cfg.stateDir}/code";
      defaultText = literalExpression ''"''${stateDir}/code"'';
      description = ''
        Working directory for the server. Every session starts here.
        Must not be the home directory: trust is never saved there, so the
        server would exit with "Workspace not trusted" on every start.
      '';
    };

    name = mkOption {
      type = types.str;
      default = config.networking.hostName;
      description = "Session title shown in the claude.ai/code session list.";
    };

    spawn = mkOption {
      type = types.enum [ "same-dir" "worktree" "session" ];
      default = "same-dir";
      description = ''
        How sessions are created. `worktree` gives each session its own git
        worktree, so `directory` must be a git repository.
      '';
    };

    capacity = mkOption {
      type = types.nullOr types.ints.positive;
      default = null;
      description = "Max concurrent sessions (Claude Code's default is 32). Ignored for spawn = session.";
    };

    extraPackages = mkOption {
      type = types.listOf types.package;
      default = [ ];
      example = literalExpression "[ pkgs.go pkgs.kubectl ]";
      description = "Extra tools on PATH for Claude's sessions.";
    };

    environmentFile = mkOption {
      type = types.nullOr types.path;
      default = null;
      example = literalExpression ''config.age.secrets."claude-gh-token".path'';
      description = ''
        Optional env file (e.g. an agenix secret) for the service. Intended
        for `GH_TOKEN=` with a fine-grained GitHub token scoped to just the
        repos Claude should push to, instead of SSH keys.
      '';
    };

    memoryMax = mkOption {
      type = types.nullOr types.str;
      default = "4G";
      description = "systemd MemoryMax for the server and every session it runs.";
    };

    cpuQuota = mkOption {
      type = types.nullOr types.str;
      default = "200%";
      description = "systemd CPUQuota (100% = one core).";
    };

    sandbox = {
      allowedDomains = mkOption {
        type = types.listOf types.str;
        default = [
          "github.com"
          "*.github.com"
          "*.githubusercontent.com"
          "cache.nixos.org"
          "registry.npmjs.org"
          "pypi.org"
          "files.pythonhosted.org"
          "proxy.golang.org"
          "sum.golang.org"
        ];
        description = ''
          Hosts sandboxed commands may reach. Everything else is denied.
          Claude's own API traffic doesn't go through this list.
        '';
      };

      allowNixDaemon = mkOption {
        type = types.bool;
        default = true;
        description = "Let sandboxed commands talk to the nix daemon socket.";
      };

      weakerNested = mkOption {
        type = types.bool;
        default = false;
        description = ''
          Set enableWeakerNestedSandbox. Needed when this runs inside a
          container, where bubblewrap can't mount a fresh /proc.
        '';
      };
    };
  };

  config = mkIf cfg.enable {

    assertions = [{
      assertion = config.security.allowUserNamespaces;
      message = "claude-remote-control: Claude Code's sandbox (bubblewrap) needs user namespaces.";
    }];

    users.users.${cfg.user} = {
      isSystemUser = true;
      uid = cfg.uid;
      group = cfg.user;
      home = home;
      createHome = true;
      # A real shell, so `sudo -u claude -i` works for the one-time login.
      shell = pkgs.bashInteractive;
    };
    users.groups.${cfg.user}.gid = cfg.uid;

    # On PATH system-wide for the one-time login step above.
    environment.systemPackages = [ cfg.package ];

    environment.etc."claude-code/managed-settings.d/claude-remote-control.json".text =
      builtins.toJSON managedSettings;

    systemd.tmpfiles.rules = [
      "d ${home} 0750 ${cfg.user} ${cfg.user} -"
      "d ${cfg.directory} 0750 ${cfg.user} ${cfg.user} -"
    ];

    systemd.services.claude-remote-control = {
      description = "Claude Code Remote Control server";
      wantedBy = [ "multi-user.target" ];
      wants = [ "network-online.target" ];
      after = [ "network-online.target" ];

      # Sessions run shell commands through this PATH, so give them the
      # basics they'd have in a login shell, plus the sandbox's own deps.
      path = with pkgs; [
        bash
        coreutils
        findutils
        gnugrep
        gnused
        gawk
        git
        gh
        openssh
        ripgrep
        jq
        curl
        bubblewrap
        socat
        config.nix.package
      ] ++ cfg.extraPackages;

      environment = {
        # Nix owns the binary; the self-updater can't write to the store anyway.
        DISABLE_AUTOUPDATER = "1";
      };

      serviceConfig = {
        User = cfg.user;
        Group = cfg.user;
        WorkingDirectory = cfg.directory;
        EnvironmentFile = mkIf (cfg.environmentFile != null) cfg.environmentFile;
        ExecStart = utils.escapeSystemdExecArgs ([
          "${cfg.package}/bin/claude"
          "remote-control"
          "--name"
          cfg.name
          "--spawn"
          cfg.spawn
        ] ++ optionals (cfg.capacity != null && cfg.spawn != "session") [
          "--capacity"
          (toString cfg.capacity)
        ]);

        # The server exits after ~10 minutes without network, and on auth
        # or trust errors. Keep bringing it back, but back off so a missing
        # login doesn't spin.
        Restart = "always";
        RestartSec = "30s";

        ## Hardening ##########################################################
        # Whole OS read-only; only Claude's home is writable.
        ProtectSystem = "strict";
        ReadWritePaths = [ home ];
        # /home, /root and /run/user are hidden.
        ProtectHome = true;
        PrivateTmp = true;
        PrivateDevices = true;
        NoNewPrivileges = true;
        CapabilityBoundingSet = "";
        AmbientCapabilities = "";
        RestrictSUIDSGID = true;
        ProtectKernelModules = true;
        ProtectControlGroups = true;
        ProtectClock = true;
        ProtectHostname = true;
        LockPersonality = true;
        RestrictRealtime = true;
        # Netlink is for bubblewrap bringing up loopback in its net namespace.
        RestrictAddressFamilies = [ "AF_UNIX" "AF_INET" "AF_INET6" "AF_NETLINK" ];
        UMask = "0077";

        # Deliberately NOT set, because they break Claude's sandbox:
        # - RestrictNamespaces: bubblewrap needs user/mount/net/pid namespaces.
        # - ProtectKernelTunables, ProtectKernelLogs, ProtectProc: they
        #   overmount parts of /proc, and the kernel then refuses the fresh
        #   /proc mount bubblewrap makes ("Can't mount proc on /newroot/proc").
        # - SystemCallFilter=@system-service: excludes the mount syscalls
        #   bubblewrap uses.
        # - MemoryDenyWriteExecute: breaks the JIT in Claude Code's runtime.

        ## Resource limits ####################################################
        MemoryMax = mkIf (cfg.memoryMax != null) cfg.memoryMax;
        CPUQuota = mkIf (cfg.cpuQuota != null) cfg.cpuQuota;
        TasksMax = 2048;
      };

      # Don't give up after repeated failures (e.g. a long outage).
      startLimitIntervalSec = 0;
    };
  };
}
