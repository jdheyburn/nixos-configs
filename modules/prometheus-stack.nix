{ config, pkgs, lib, ... }:

with lib;

let grafanaPort = 2342;
in {

  networking.firewall.allowedTCPPorts = [ grafanaPort ];

  services.grafana = {
    enable = true;
    domain = "grafana.svc.joannet.casa";
    port = grafanaPort;
    addr = "0.0.0.0";
  };

 services.prometheus = {
    enable = true;
    port = 9001;
    exporters = {
      node = {
        enable = true;
        enabledCollectors = [ "systemd" ];
        port = 9002;
      };
    };
    scrapeConfigs = [
      {
	job_name = "dennis";
	static_configs = [{
	  targets = [ "127.0.0.1:${toString config.services.prometheus.exporters.node.port}" ];
	}];
      }
    ];
  };
}
