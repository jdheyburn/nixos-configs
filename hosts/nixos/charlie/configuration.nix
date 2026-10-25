{ catalog, config, lib, pkgs, myUtils, ... }:
{

  imports = [ ./hardware-configuration.nix ./networking.nix ];

  ###############################################################################
  ## General
  ###############################################################################

  system.stateVersion = "22.11";

  zramSwap.enable = true;

  networking.hostName = "charlie";
  networking.firewall.allowedTCPPorts = [ 22 3000 8096 ];
  #   networking.domain = "";

  services.openssh.enable = true;

  ###############################################################################
  ## Modules
  ###############################################################################

  # TODO these secrets should be defined in the module
  age.secrets."restic-small-files-password".file =
    myUtils.secrets.file "restic-small-files-password";
  age.secrets."rclone.conf".file = myUtils.secrets.file "rclone.conf";

  modules.backup = {
    obsidian = {
      enable = true;
      rcloneConfigFile = config.age.secrets."rclone.conf".path;
      missingAttachmentsHealthcheck =
        "https://healthchecks.${catalog.domain.service}/ping/0453e7de-cfc6-4460-96bf-7b5a4143b869";
      staleMirrorHealthcheck =
        "https://healthchecks.${catalog.domain.service}/ping/2d9463f8-b671-4622-891e-bb1ca65009cb";
      history.enable = true;
    };
    small-files = {
      enable = true;
      rcloneConfigFile = config.age.secrets."rclone.conf".path;
      passwordFile = config.age.secrets."restic-small-files-password".path;
      healthcheck =
        "https://healthchecks.${catalog.domain.service}/ping/92e823bb-17ff-4d94-8a41-fcad88fb3b21";
    };
  };
  modules.caddy.enable = true;
  # Claude Code Remote Control, inside a container rather than on the host
  # Fine-grained token for nixos-configs and scratch, as GH_TOKEN=<token>.
  # A real file in its own directory: the directory is bind-mounted into the
  # container, and a symlink would point outside it.
  age.secrets."claude-gh-token" = {
    file = myUtils.secrets.file "claude-gh-token";
    path = "/run/claude-secrets/gh-token";
    symlink = false;
    owner = "claude";
    group = "claude";
    mode = "0400";
  };
  modules.claude-container = {
    enable = true;
    externalInterface = "eth0";
    githubTokenFile = config.age.secrets."claude-gh-token".path;
    service.servers = {
      nixos-configs.repo = "jdheyburn/nixos-configs";
      scratch.repo = "jdheyburn/scratch";
    };
    service.connectorUrls = [
      "https://mcp-proxy.anthropic.com/v1/mcp/mcpsrv_014Fj7srWvLMyCuRCS8J9W3d" # Claude Docs
      "https://mcp-proxy.anthropic.com/v1/mcp/mcpsrv_018FS2YdTHWo4C4jDbymwhVk" # Todoist
    ];
  };
  modules.dashy.enable = true;
  modules.lubelogger.enable = true;
  modules.monitoring.enable = true;
  modules.nfs-client.enable = true;
  # Off until it's onboarded properly
  modules.paperless.enable = false;
  modules.prometheusStack = {
    enable = true;
    blackbox.enable = true;
    grafana.enable = true;
    loki.enable = true;
    victoriametrics.enable = true;
  };
  modules.remote-builder.enable = true;

  environment.systemPackages = [
    pkgs.ffmpeg
    pkgs.restic
  ];

  environment.sessionVariables = {
    LD_LIBRARY_PATH = "${pkgs.stdenv.cc.cc.lib}/lib/";
  };

  programs.nix-ld.enable = true;

  services.jellyfin.enable = false;
  services.jellyfin.user = "jdheyburn";
  services.jellyfin.group = "users";

  # For tailscale exit nodes
  #boot.kernel.sysctl = {
  #  "net.ipv4.ip_forward" = 1;
  #  "net.ipv6.conf.all.forwarding" = 1;
  #};
}
