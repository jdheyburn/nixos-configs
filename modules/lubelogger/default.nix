# Inspired from https://github.com/camillemndn/infra/blob/422879d25d6f1bc1d9e4d028242df2258b9ed3f0/modules/services/web-apps/lubelogger/default.nix#L9

{ catalog, config, pkgs, lib, ... }:

with lib;

let
  cfg = config.modules.lubelogger;
in
{
  options = {
    modules.lubelogger = {
      enable = mkEnableOption "Lubelogger, a self-hosted, open-source, web-based vehicle maintenance and fuel milage tracker";

      package = mkPackageOption pkgs "lubelogger" { };

      dataDir = mkOption {
        description = "Path to Lubelogger config and metadata.";
        default = "/var/lib/lubelogger";
        type = types.str;
      };

      settings = lib.mkOption {
        type = lib.types.submodule { freeformType = with lib.types; attrsOf str; };
        default = { };
        example = {
          LUBELOGGER_ALLOWED_FILE_EXTENSIONS = "";
          LUBELOGGER_LOGO_URL = "";
        };
        description = ''
          Additional configuration for LubeLogger, see
          <https://docs.lubelogger.com/Environment%20Variables>
          for supported values.
        '';
      };

      port = mkOption {
        description = "The TCP port Lubelogger will listen on.";
        default = catalog.services.lubelogger.port;
        type = types.port;
      };

      user = mkOption {
        description = "User account under which Lubelogger runs.";
        default = "lubelogger";
        type = types.str;
      };

      group = mkOption {
        description = "Group under which Lubelogger runs.";
        default = "lubelogger";
        type = types.str;
      };

      openFirewall = mkOption {
        description = "Open ports in the firewall for the Lubelogger web interface.";
        default = false;
        type = types.bool;
      };
    };
  };

  config = mkIf cfg.enable {
    services.caddy.virtualHosts."lubelogger.svc.joannet.casa".extraConfig = ''
      tls {
        dns cloudflare {env.CLOUDFLARE_API_TOKEN}
        # Below required to get TLS to work on non-local hosts (i.e. charlie)
        resolvers 8.8.8.8
      }
      reverse_proxy localhost:${toString catalog.services.lubelogger.port}
    '';

    modules.lubelogger.settings = {
      DOTNET_CONTENTROOT = cfg.dataDir;
      LC_ALL = "en_GB";
      LANG = "en_GB";
      UseDarkMode = "true";
      EnableAuth = "true";
      UserNameHash = "b53bdd407e178e9a00eb6d1b5cd5633564030ffb785904f7096109255f01631a";
      UserPasswordHash = "ab8cd8ab7d3930490ec8233671f4259ebadd84148e9226ac8081097be5c417d1";
      # Kestrel__Endpoints__Http__Url = "http://localhost:${toString cfg.port}";
    };

    systemd.services.lubelogger = {
      description = "Lubelogger, a self-hosted, open-source, web-based vehicle maintenance and fuel milage tracker";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];
      environment = cfg.settings;

      serviceConfig = {
        Type = "simple";
        User = cfg.user;
        Group = cfg.group;
        StateDirectory = baseNameOf cfg.dataDir;
        WorkingDirectory = cfg.dataDir; # "${cfg.package}/lib/lubelogger";
        ExecStartPre = pkgs.writeShellScript "lubelogger-prestart" ''
          cd $STATE_DIRECTORY
          if [ ! -e .nixos-lubelogger-contentroot-copied ]; then
            cp -r ${cfg.package}/lib/lubelogger/* .
            chmod -R 744 .
            touch .nixos-lubelogger-contentroot-copied
          fi
        '';
        ExecStart = "${lib.getExe cfg.package}";
        Restart = "on-failure";
        # BindPaths = [
        #   "${cfg.dataDir}/config:${cfg.package}/lib/lubelogger/config"
        #   "${cfg.dataDir}/data:${cfg.package}/lib/lubelogger/data"
        #   "${cfg.dataDir}/temp:${cfg.package}/lib/lubelogger/wwwroot/temp"
        #   "${cfg.dataDir}/images:${cfg.package}/lib/lubelogger/wwwroot/images"
        # ];
      };
    };

    users.users = mkIf (cfg.user == "lubelogger") {
      lubelogger = {
        isSystemUser = true;
        inherit (cfg) group;
        home = cfg.dataDir;
      };
    };

    users.groups = mkIf (cfg.group == "lubelogger") { lubelogger = { }; };

    networking.firewall = mkIf cfg.openFirewall { allowedTCPPorts = [ cfg.port ]; };

    # Inspiration from https://github.com/firecat53/nixos/blob/52269c82a1195d70a4209d75ed8cf774234510ca/hosts/homeserver/services/lubelogger.nix#L7
    # virtualisation.oci-containers.containers.lubelogger = {
    #   image = "lissy93/dashy:${version}";
    #   volumes = [ "${configFile}:/app/user-data/conf.yml" ];
    #   ports = [ "${toString catalog.services.home.port}:8080" ];
    # };


  };
}
