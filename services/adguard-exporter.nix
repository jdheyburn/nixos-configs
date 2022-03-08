{ config, lib, buildGoModule, fetchFromGitHub, ...}:


buildGoModule rec {
    pname = "adguard-exporter";
    version = "1.14";

    src = fetchFromGitHub {
        owner = "ebrianne";
        repo = "adguard-exporter";
        rev = "v${version}";
        # dummy for now
        sha256 = "sha256-xh9s1xAhIeEmeDprl7iPdE6pxmxZjzgMvilobiIoJp0=";
    };
    # dummy
    vendorSha256 = "sha256-xh9s1xAhIeEmeDprl7iPdE6pxmxZjzgMvilobiIoJp0=";

    meta = with lib; {
        description = "Adguard exporter based on eko/pihole-exporter ";
        homepage = "https://github.com/ebrianne/adguard-exporter";
        license = licenses.mit;
        maintainers = with maintainers; [ jdheyburn ];
    };
};

with lib;
let
    cfg = config.services.adguard-exporter;
in
{
    options.services.adguard-exporter = {
        enable = mkEnableOption "adguard-exporter";
    };

    config = mkIf cfg.enable {
        users.groups.adguard-exporter = { };
        users.users.adguard-exporter = {
            description = "adguard-exporter Service User";
            group = "adguard-exporter";
            isSystemUser = true;
        };

        systemd.services.adguard-exporter = {
            wantedBy = [ "multi-user.target" ];
            after = [ "network.target" ];
            serviceConfig = {
                ExecStart = "${adguard-exporter}";
                Restart = "always";
                PrivateTmp = true;
                ProtectHome = true; 
                ProtectSystem = "full";
                DevicePolicy = "closed";
                NoNewPrivileges = true;
                User = "adguard-exporter";
                WorkingDirectory = "/tmp";
            };

        };
    }
}
