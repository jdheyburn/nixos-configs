{ config, pkgs, lib, llm-agents, herdr, ... }:

# Always-on Claude Code Remote Control servers, steerable from claude.ai/code
# and the Claude app. Each server works in one GitHub repo and runs in its own
# Herdr workspace, so a prompt that only the terminal can show can still be
# answered by attaching over SSH. Three layers keep it from breaking the host:
#
#   1. A dedicated `claude` system user: no wheel, no SSH keys to other
#      nodes, no deploy-rs access. Worst case it trashes its own home.
#   2. systemd hardening: the OS is read-only apart from that home, other
#      users' homes are hidden, and memory/CPU are capped.
#   3. Claude Code's own sandbox (bubblewrap + socat) around every shell
#      command, enforced from managed settings so a repo can't loosen it.
#
# Repos are cloned and workspace trust is seeded on start. The one manual
# step after the first deploy is the login, because Remote Control rejects
# setup-token and API-key auth:
#
#   sudo -u claude -i claude auth login        # choose the claude.ai option
#
# To answer a prompt from a terminal: sudo -u claude -i herdr

with lib;

let
  cfg = config.modules.claude-remote-control;
  home = cfg.stateDir;
  system = pkgs.stdenv.hostPlatform.system;
  herdrPkg = herdr.packages.${system}.default;
  claude = "${cfg.package}/bin/claude";

  serverDir = name: "${home}/code/${name}";
  # Where a worktree-mode server runs: its own worktree on a detached HEAD.
  # The server pre-creates a session in its cwd, and this keeps that
  # session out of the main checkout. It sits outside .claude/worktrees so
  # Claude's worktree cleanup leaves it alone.
  homeDir = name: "${home}/rc/${name}";

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
        # No unix sockets at all. In particular not the nix daemon: on a host
        # with nix.settings.sandbox = false its builds run unsandboxed as
        # root's builders, outside this service's walls.
        allowAllUnixSockets = false;
        allowLocalBinding = false;
      };

      # Package caches, so uv and prek don't start cold in every session. The
      # directories are created by tmpfiles below.
      filesystem.allowWrite = [ "~/.cache/uv" "~/.cache/prek" ];

      credentials.files = map (path: { inherit path; mode = "deny"; }) [
        # Claude's own login is a full-scope token: keep it away from the
        # commands Claude runs.
        "~/.claude/.credentials.json"
        "~/.config/gh"
        "~/.ssh"
        # Herdr's socket lives here. A command that could reach it could type
        # into a pane's shell, which runs outside the sandbox.
        "~/.config/herdr"
      ];
    };

    # Only these claude.ai connectors load. Anything added to the account
    # later stays off until it's listed here.
    allowedMcpServers = [
      { serverName = "claude.ai Claude Docs"; }
      { serverName = "claude.ai Todoist"; }
    ];

    permissions = {
      # The file tools sit outside the bash sandbox, so deny them separately.
      # The git and gh rules are a soft guard: changes go through PRs that
      # Joe merges.
      deny = [
        "Read(~/.claude/.credentials.json)"
        "Edit(~/.claude/.credentials.json)"
        "Read(~/.config/gh/**)"
        "Read(~/.config/herdr/**)"
        "Bash(gh pr merge:*)"
        "Bash(git push * main)"
        "Bash(git push * main:*)"
        "Bash(git push * HEAD:main)"
      ];
      disableBypassPermissionsMode = "disable";
    };
  };

  # Managed memory: loaded in every session and not overridable by the user
  # or a repo's CLAUDE.md.
  managedMemory = ''
    # Running on ${cfg.hostLabel}

    You run on ${cfg.hostLabel}, started from Joe's phone or browser through Remote Control.

    - Push branches and open PRs. Never push to `main` and never merge a PR. Joe reviews and merges.
    - Nix isn't available here. Don't try to build or evaluate anything. Say in every PR that touches Nix files that the change is unbuilt.
    - Stage files by path. `git add -A` fails on empty placeholder files the sandbox creates in the repo (`.bashrc`, `.gitconfig`, `.mcp.json` and similar).
    - The Obsidian vault isn't available here. Skip project-log updates and put decisions in the PR description.
  '';

  # Commands sessions can run, plus the sandbox's own deps. Herdr panes
  # start a login shell, which takes PATH from /etc/profile rather than the
  # service, so these go on the claude user's profile as well.
  tools = with pkgs; [
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
    herdrPkg
    python3
    uv
    prek
  ] ++ cfg.extraPackages;

  # Empty files and directories the sandbox mounts over protected paths in a
  # session's working directory. They show up as untracked and make
  # `git add -A` fail, so every clone ignores them. Worktrees share the
  # main checkout's info/exclude.
  placeholderExcludes = pkgs.writeText "claude-sandbox-excludes" ''
    # Claude Code sandbox placeholders, added by claude-remote-control
    /.bash_profile
    /.bashrc
    /.profile
    /.zprofile
    /.zshrc
    /.gitconfig
    /.gitmodules
    /.ripgreprc
    /.mcp.json
    /.idea
    /.vscode
    /.claude/worktrees/
  '';

  # One loop per server. It clones the repo first if it's missing: inside a
  # container the network only comes up once boot has finished, so the
  # clone can't happen during boot. Without --no-create-session-in-dir, a
  # restarted server resumes the sessions it was serving (for about four
  # hours), so a deploy doesn't lose them. The server exits after ~10 minutes
  # without network and on auth errors, so keep bringing it back, with a
  # pause so a missing login doesn't spin.
  loopFor = name: server: pkgs.writeShellScript "claude-rc-loop-${name}" ''
    until [ -d ${serverDir name}/.git ]; do
      ${pkgs.git}/bin/git clone https://github.com/${server.repo}.git ${serverDir name} && break
      echo "clone of ${server.repo} failed; retrying in 30s"
      sleep 30
    done
    cd ${serverDir name}
    exclude=.git/info/exclude
    if ! ${pkgs.gnugrep}/bin/grep -qsF "added by claude-remote-control" "$exclude"; then
      mkdir -p .git/info
      cat ${placeholderExcludes} >> "$exclude"
    fi
    ${optionalString (server.spawn == "worktree") ''
      # Kept across restarts: the server only brings its sessions back when
      # it starts again in the same directory.
      until [ -e ${homeDir name}/.git ]; do
        ${pkgs.git}/bin/git fetch -q origin \
          && ${pkgs.git}/bin/git worktree add -q --detach ${homeDir name} origin/HEAD \
          && break
        echo "creating ${homeDir name} failed; retrying in 30s"
        sleep 30
      done
      cd ${homeDir name}
    ''}
    while :; do
      ${escapeShellArgs ([
        claude
        "remote-control"
        "--name"
        server.displayName
        "--spawn"
        server.spawn
      ] ++ optionals (server.capacity != null && server.spawn != "session") [
        "--capacity"
        (toString server.capacity)
      ])}
      echo "claude remote-control exited with status $?; restarting in 30s"
      sleep 30
    done
  '';

  # Pre-trusts every server directory and marks the "Enable Remote Control?"
  # prompt as answered. Trust is keyed on the path, so it can
  # be seeded before the loop clones the repo. Nothing here needs the
  # network: the service runs during boot, and a slow step here delays boot
  # past the container's start timeout.
  prepare = pkgs.writeShellApplication {
    name = "claude-remote-control-prepare";
    runtimeInputs = [ pkgs.coreutils ];
    text = ''
      mkdir -p ${home}/code
      ${optionalString (cfg.servers != { }) ''
        ${pkgs.python3}/bin/python3 -E -s ${./seed_trust.py} \
          --claude-json ${home}/.claude.json \
          ${concatMapStringsSep " " (name: "--dir ${serverDir name}") (attrNames cfg.servers)}
      ''}
    '';
  };

  # Starts one Herdr workspace per server and runs its loop in the root pane.
  # Herdr restores its last session on start, so a workspace left over from
  # the previous run is closed first rather than kept alongside a new one.
  herdrSetup = pkgs.writeShellApplication {
    name = "claude-herdr-setup";
    runtimeInputs = [ herdrPkg pkgs.jq pkgs.coreutils pkgs.gnugrep ];
    text = ''
      for _ in $(seq 1 30); do
        if herdr status server | grep -q 'status: running'; then break; fi
        sleep 1
      done
      herdr status server | grep -q 'status: running'

      ${concatStrings (mapAttrsToList (name: server: ''
        herdr workspace list \
          | jq -r --arg label ${name} '.result.workspaces[] | select(.label == $label) | .workspace_id' \
          | while read -r id; do herdr workspace close "$id"; done
        pane=$(herdr workspace create --cwd ${home}/code --label ${name} --no-focus \
          | jq -r '.result.root_pane.pane_id')
        herdr pane run "$pane" ${loopFor name server}
      '') cfg.servers)}
    '';
  };
in
{

  options.modules.claude-remote-control = {
    enable = mkEnableOption "always-on Claude Code Remote Control servers, reachable from claude.ai/code and the Claude app";

    package = mkOption {
      type = types.package;
      default = llm-agents.packages.${system}.claude-code;
      description = "Claude Code package to run. Same source as the desktop profile.";
    };

    user = mkOption {
      type = types.str;
      default = "claude";
      description = ''
        Dedicated system user the servers run as. It is created by this
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
      description = "Home of the user: login, trust, Herdr state and repos live here. The only writable path.";
    };

    hostLabel = mkOption {
      type = types.str;
      default = config.networking.hostName;
      description = "Machine name used in session titles and Claude's instructions. Inside a container, set it to the host's name.";
    };

    servers = mkOption {
      default = { };
      example = literalExpression ''{ nixos-configs.repo = "jdheyburn/nixos-configs"; }'';
      description = ''
        One Remote Control server per GitHub repo. Each works in a clone at
        ''${stateDir}/code/<name>, made on first start, and runs in a Herdr
        workspace labelled <name>.
      '';
      type = types.attrsOf (types.submodule ({ name, ... }: {
        options = {
          repo = mkOption {
            type = types.str;
            example = "jdheyburn/nixos-configs";
            description = "GitHub owner/repo, cloned over HTTPS with GH_TOKEN.";
          };

          displayName = mkOption {
            type = types.str;
            default = "${cfg.hostLabel}-${name}";
            description = "Session title shown in the claude.ai/code session list.";
          };

          spawn = mkOption {
            type = types.enum [ "same-dir" "worktree" "session" ];
            default = "worktree";
            description = "How sessions are created. `worktree` gives each session its own git worktree.";
          };

          capacity = mkOption {
            type = types.nullOr types.ints.positive;
            default = null;
            description = "Max concurrent sessions (Claude Code's default is 32). Ignored for spawn = session.";
          };
        };
      }));
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
      description = "systemd MemoryMax for the servers and every session they run.";
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
      # A real shell, so `sudo -u claude -i` works for the login and attach.
      shell = pkgs.bashInteractive;
      packages = tools;
    };
    users.groups.${cfg.user}.gid = cfg.uid;

    # Settings, plugins and skills shared with the desktop profile.
    home-manager.users.${cfg.user} = {
      imports = [ ../../../home/profiles/agent ];
      home.stateVersion = config.system.stateVersion;
      # Attaching usually happens from a pane of the laptop's herdr, which
      # keeps ctrl+space for itself.
      modules.herdr.prefix = "ctrl+b";
    };

    # Prebuilt binaries from PyPI wheels (ruff, ty) expect a standard
    # dynamic loader.
    programs.nix-ld.enable = true;

    # On PATH system-wide for the one-time login step above.
    environment.systemPackages = [ cfg.package ];

    environment.etc."claude-code/managed-settings.d/claude-remote-control.json".text =
      builtins.toJSON managedSettings;
    environment.etc."claude-code/CLAUDE.md".text = managedMemory;

    # Pushes go over HTTPS with GH_TOKEN from environmentFile, through gh.
    programs.git = {
      enable = true;
      config = {
        credential."https://github.com".helper = "!${pkgs.gh}/bin/gh auth git-credential";
        user = {
          name = "Joseph Heyburn";
          email = "jdheyburn@gmail.com";
        };
      };
    };

    systemd.tmpfiles.rules = [
      "d ${home} 0750 ${cfg.user} ${cfg.user} -"
      "d ${home}/code 0750 ${cfg.user} ${cfg.user} -"
      "d ${home}/rc 0750 ${cfg.user} ${cfg.user} -"
      "d ${home}/.cache 0700 ${cfg.user} ${cfg.user} -"
      "d ${home}/.cache/uv 0700 ${cfg.user} ${cfg.user} -"
      "d ${home}/.cache/prek 0700 ${cfg.user} ${cfg.user} -"
    ];

    systemd.services.claude-remote-control = {
      description = "Claude Code Remote Control servers, under Herdr";
      wantedBy = [ "multi-user.target" ];
      wants = [ "network-online.target" ];
      after = [ "network-online.target" ];

      path = tools;

      environment = {
        HOME = home;
        # Herdr panes start this shell.
        SHELL = "${pkgs.bashInteractive}/bin/bash";
        # Nix owns the binary; the self-updater can't write to the store anyway.
        DISABLE_AUTOUPDATER = "1";
        # uv's downloaded Pythons are built for other distros; use Nix's.
        UV_PYTHON_DOWNLOADS = "never";
      };

      serviceConfig = {
        User = cfg.user;
        Group = cfg.user;
        WorkingDirectory = home;
        EnvironmentFile = mkIf (cfg.environmentFile != null) cfg.environmentFile;
        ExecStartPre = getExe prepare;
        ExecStart = "${getExe herdrPkg} server";
        ExecStartPost = getExe herdrSetup;

        # The per-server loops handle claude exiting; this brings Herdr back.
        Restart = "always";
        RestartSec = "30s";

        ## Hardening ##########################################################
        # Whole OS read-only; only Claude's home is writable.
        ProtectSystem = "strict";
        ReadWritePaths = [ home ];
        # /home, /root and /run/user are hidden.
        ProtectHome = true;
        # NixOS containers always bind the host's daemon socket in. Hide it
        # from the servers and everything they start, on top of the sandbox.
        InaccessiblePaths = [ "-/nix/var/nix/daemon-socket" ];
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
