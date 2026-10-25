{ config, lib, flake-self, llm-agents, herdr, ... }:

# Runs the claude-remote-control service inside a NixOS container
# (systemd-nspawn), so the host's filesystem, users and services are out of
# reach entirely. The container has its own network namespace, NATed out
# through the host, and can't reach the LAN, the tailnet or the host's own
# services. Its state (login, repos) lives under
# /var/lib/nixos-containers/<name>, so throwing it away is:
#
#   sudo nixos-container destroy claude   # then redeploy
#
# One-time setup after the first deploy, from the host:
#
#   sudo nixos-container root-login claude
#   sudo -u claude -i claude auth login        # choose the claude.ai option
#   systemctl restart claude-remote-control && exit
#
# See README.md for attaching to Herdr and the rest of the setup.
#
# Don't also enable modules.claude-remote-control on the host.

with lib;

let
  cfg = config.modules.claude-container;
  veth = "ve-${cfg.name}";
  hostAddr = "${cfg.subnet}.1";
  containerAddr = "${cfg.subnet}.2";
  chain = "nixos-${cfg.name}-fwd";
in
{

  options.modules.claude-container = {
    enable = mkEnableOption "Claude Code Remote Control inside an isolated NixOS container";

    name = mkOption {
      type = types.strMatching "[a-z0-9-]{1,11}";
      default = "claude";
      description = "Container name. Short: it also names the ve-<name> interface (15 char limit).";
    };

    externalInterface = mkOption {
      type = types.str;
      example = "eth0";
      description = "Host interface the container's traffic is NATed out of.";
    };

    subnet = mkOption {
      type = types.str;
      default = "10.233.7";
      description = "/24 prefix for the host<->container veth pair (.1 host, .2 container).";
    };

    blockedNetworks = mkOption {
      type = types.listOf types.str;
      default = [
        "10.0.0.0/8"
        "172.16.0.0/12"
        "192.168.0.0/16"
        "100.64.0.0/10" # tailscale
        "169.254.0.0/16" # link-local, incl. cloud metadata endpoints
      ];
      description = ''
        Destinations the container may never reach (LAN, tailnet, metadata).
        The host's own addresses are always blocked too.
      '';
    };

    bindCode = mkOption {
      type = types.nullOr types.str;
      default = null;
      example = "/srv/claude-code";
      description = ''
        Optional host directory bind-mounted read-write as the container's
        code directory, so you can get at Claude's repos from the host.
        Leave null to keep everything inside the container.
      '';
    };

    uid = mkOption {
      type = types.int;
      default = 3500;
      description = "Fixed UID/GID of the claude user inside the container, so bindCode ownership is stable.";
    };

    service = mkOption {
      type = types.attrsOf types.anything;
      default = { };
      example = literalExpression ''{ spawn = "worktree"; extraPackages = [ pkgs.go ]; }'';
      description = "Extra modules.claude-remote-control options for inside the container.";
    };
  };

  config = mkIf cfg.enable {

    networking.nat = {
      enable = true;
      internalInterfaces = [ veth ];
      inherit (cfg) externalInterface;
    };

    # Host-side walls, independent of anything inside the container. The
    # FORWARD rules live in their own chain, flushed on every firewall
    # (re)start so reloads don't stack duplicates.
    networking.firewall.extraCommands = ''
      # The container can't open connections to the host itself.
      iptables -I nixos-fw -i ${veth} -j DROP

      # ...or be forwarded onto the LAN / tailnet.
      iptables -N ${chain} 2>/dev/null || true
      iptables -F ${chain}
      ${concatMapStrings (net: ''
        iptables -A ${chain} -d ${net} -j DROP
      '') cfg.blockedNetworks}
      iptables -A ${chain} -o tailscale0 -j DROP
      iptables -D FORWARD -i ${veth} -j ${chain} 2>/dev/null || true
      iptables -I FORWARD -i ${veth} -j ${chain}
    '';
    networking.firewall.extraStopCommands = ''
      iptables -D FORWARD -i ${veth} -j ${chain} 2>/dev/null || true
      iptables -F ${chain} 2>/dev/null || true
      iptables -X ${chain} 2>/dev/null || true
    '';

    containers.${cfg.name} = {
      autoStart = true;
      privateNetwork = true;
      hostAddress = hostAddr;
      localAddress = containerAddr;
      # Not ephemeral: the claude.ai login has to survive restarts.
      ephemeral = false;

      bindMounts = mkIf (cfg.bindCode != null) {
        "/var/lib/claude-remote-control/code" = {
          hostPath = cfg.bindCode;
          isReadOnly = false;
        };
      };

      # The container is evaluated separately, so it needs the flake inputs
      # the inner modules and the shared home-manager profile take.
      specialArgs = {
        inherit llm-agents herdr;
        inherit (flake-self) inputs;
      };

      config = { lib, pkgs, inputs, ... }: {
        imports = [
          inputs.home-manager.nixosModules.home-manager
          ../claude-remote-control
        ];

        home-manager = {
          useGlobalPkgs = true;
          useUserPackages = true;
          extraSpecialArgs = {
            inherit inputs;
            system = pkgs.stdenv.hostPlatform.system;
          };
        };

        system.stateVersion = config.system.stateVersion;
        time.timeZone = config.time.timeZone;

        # Don't depend on the host for DNS (its ports are blocked).
        networking.nameservers = [ "1.1.1.1" "8.8.8.8" ];
        networking.useHostResolvConf = lib.mkForce false;
        networking.firewall.enable = true;

        modules.claude-remote-control = {
          enable = true;
          inherit (cfg) uid;
          # Inside, hostName is the container's name; sessions and Claude's
          # instructions should name the host.
          hostLabel = config.networking.hostName;
          # bubblewrap can't mount a fresh /proc inside nspawn; the
          # container is the real boundary here.
          sandbox.weakerNested = true;
        } // cfg.service;
      };
    };

    # Owns host paths bind-mounted into the container (the GitHub token),
    # with the same uid as the container's claude user.
    users.users.claude = {
      isSystemUser = true;
      inherit (cfg) uid;
      group = "claude";
    };
    users.groups.claude.gid = cfg.uid;

    # Make sure the bind-mount source exists on the host.
    systemd.tmpfiles.rules = optional (cfg.bindCode != null)
      "d ${cfg.bindCode} 0750 ${toString cfg.uid} ${toString cfg.uid} -";
  };
}
