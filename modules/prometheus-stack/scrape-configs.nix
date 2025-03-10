{ catalog, config, flake-self, lib }:

with lib;

let
  # TODO review whether shouldScrape attribute is necessary
  nodeExporterTargets =
    map
      (node:
        "${node.hostName}.${catalog.domain.tailscale}"
      )
      (attrValues (filterAttrs (node_name: node_def: node_def ? "shouldScrape" && node_def.shouldScrape) catalog.nodes));

  # TODO isEnabled and shouldDNS are duplicated from modules/dns/default.nix - remove the duplication
  isEnabled = moduleName: hostName:
    let
      parts = splitString "." moduleName;
      module = builtins.foldl' (acc: part: builtins.getAttr part acc) flake-self.nixosConfigurations."${hostName}".config.modules parts;
    in
    module.enable;

  shouldDNS = service:
    # Only create DNS entries if the host that catalog.service says its running on has it enabled
    # service.modules is a list of strings that contain paths to check for enabling, see catalog.nix
    service ? "modules" && (all (x: x) (map (moduleName: isEnabled moduleName service.host.hostName) service.modules));

  caddified_services = attrValues (filterAttrs
    (svc_name: svc_def: shouldDNS svc_def)
    catalog.services);

  internal_https_targets =
    let
      getPath = service:
        optionalString (service ? "blackbox" && service.blackbox ? "path")
          service.blackbox.path;
      getHumanName = service:
        if service ? "blackbox" && service.blackbox ? "name" then
          service.blackbox.name
        else
          service.name;
    in
    map
      (service:
        "https://${service.name}.${catalog.domain.service}${getPath service};${
      getHumanName service
    };internal")
      caddified_services;

  external_targets = map (url: "https://${url};${url};external") [
    "bbc.co.uk"
    "github.com"
    "google.com"
    "jdheyburn.co.uk"
  ];

  blackbox = {
    https_targets = external_targets ++ internal_https_targets;

    # Tried this for minio and plex, as they were returning 401 and 403
    # but since these services are behind reverse proxy, the TLS check is
    # against caddy, so it would not fail if the underlying service goes down
    # TODO evaluate a blackbox on each node, that can poll for TLS services
    # tls_targets = map (service:
    #   "${service.name}.svc.joannet.casa:443;${
    #     if service ? "blackbox" && service.blackbox ? "name" then
    #       service.blackbox.name
    #     else
    #       service.name
    #   };internal")
    #   (filter (service: service.blackbox.module == "tls_connect")
    #     caddified_services);

    relabel_configs = [
      {
        source_labels = [ "__address__" ];
        regex = "(.*);(.*);(.*)"; # first is the url, thus unique for instance
        target_label = "instance";
        replacement = "$1";
      }
      {
        source_labels = [ "__address__" ];
        regex = "(.*);(.*);(.*)"; # second is humanname to use in charts
        target_label = "humanname";
        replacement = "$2";
      }
      {
        source_labels = [ "__address__" ];
        regex =
          "(.*);(.*);(.*)"; # third state whether this is testing external or internal network
        target_label = "routing";
        replacement = "$3";
      }
      {
        source_labels = [ "instance" ];
        target_label = "__param_target";
      }
      {
        target_label = "__address__";
        replacement =
          "127.0.0.1:${toString catalog.services.blackboxExporter.port}";
      }
    ];

  };

  # TODO duplicated from flake.nix - remove the duplication
  isNixOS = system: builtins.elem system [ "x86_64-linux" "aarch64-linux" ];
  nixOSNodes = attrValues
    (filterAttrs (node_name: node_def: node_def ? "system" && isNixOS node_def.system) catalog.nodes);

  promtail_targets = map
    (node:
      "${node.hostName}.${catalog.domain.tailscale}:${toString catalog.services.promtail.port}"
    )
    nixOSNodes;

in
# TODO a way to build scrape configs and set their targets dynamically
  # i.e. avoid the hardcode of hostnames in the targets
[
  # {
  #   job_name = "prometheus";
  #   scrape_interval = "5s";
  #   static_configs = [{
  #     targets = [ "localhost:${toString config.services.prometheus.port}" ];
  #   }];
  # }
  {
    job_name = "grafana";
    scrape_interval = "5s";
    static_configs = [{
      targets = [
        "localhost:${
          toString config.services.grafana.settings.server.http_port
        }"
      ];
    }];
  }
  {
    job_name = "node";
    scrape_interval = "5s";
    static_configs = [{
      targets = map
        (node:
          "${node}:${toString config.services.prometheus.exporters.node.port}")
        nodeExporterTargets;
    }];
    # Convert instance label "<hostname>:<port>" -> "<hostname>"
    # https://stackoverflow.com/questions/49896956/relabel-instance-to-hostname-in-prometheus
    relabel_configs = [{
      source_labels = [ "__address__" ];
      target_label = "instance";
      regex = "([^:]+)(:[0-9]+)?";
      replacement = "\${1}";
    }];
  }
  {
    job_name = "unifi";
    static_configs = [{
      targets = [
        "${catalog.services.unifi.host.hostName}.${catalog.domain.tailscale}:${
          toString config.services.prometheus.exporters.unpoller.port
        }"
      ];
    }];
  }
  # disabled caddy scrape since couldn't get it to reach from external location
  #{
  #  job_name = "caddy";
  #  static_configs = [{ targets = [ 
  #    "dennis.joannet.casa:2019"
  #    "dee.joannet.casa:2019"
  #  ]; }];
  #}
  # {
  #   job_name = "adguard";
  #   static_configs = [{ targets = [ "dee.joannet.casa:9617" ]; }];
  # }
  # Blackbox monitoring inspiration from:
  #   https://github.com/prometheus/blackbox_exporter#prometheus-configuration
  #   https://github.com/maxandersen/internet-monitoring/blob/master/prometheus/prometheus.yml
  {
    job_name = "blackbox-https";
    metrics_path = "/probe";
    params.module = [ "http_2xx" ];
    static_configs = [{ targets = blackbox.https_targets; }];
    relabel_configs = blackbox.relabel_configs;
  }
  # {
  #   job_name = "blackbox-tls";
  #   metrics_path = "/probe";
  #   params = { module = [ "tls_connect" ]; };
  #   static_configs = [{ targets = blackbox.tls_targets; }];
  #   relabel_configs = blackbox.relabel_configs;
  # }
  # End blackbox monitoring
  {
    job_name = "minio";
    metrics_path = "/minio/v2/metrics/cluster";
    scheme = "https";
    static_configs = [{ targets = [ "minio.${catalog.domain.service}" ]; }];
  }
  {
    job_name = "loki";
    static_configs = [{
      targets = [
        "localhost:${
           toString config.services.loki.configuration.server.http_listen_port
         }"
      ];
    }];
  }
  {
    job_name = "promtail";
    static_configs = [{ targets = promtail_targets; }];
  }
  {
    job_name = "zfs";
    static_configs = [{
      targets = [
        "dee.${catalog.domain.tailscale}:${
           toString config.services.prometheus.exporters.zfs.port
         }"
      ];
    }];
  }
]
