{ catalog, config, lib }:

with lib;

let
  nodeExporterTargets =
    map (node_name: "${node_name}.joannet.casa") (attrNames catalog.nodes);

  caddified_services =
    (filterAttrs (n: v: v ? "caddify" && v.caddify.enable) catalog.services);

  caddified_services_list = map (service_name:
    caddified_services."${service_name}" // {
      name = service_name;
    }) (attrNames caddified_services);

  internal_https_targets = map (service:
    "https://${service.name}.svc.joannet.casa${
      if service ? "blackbox" && service.blackbox ? "path" then
        service.blackbox.path
      else
        ""
    };${
      if service ? "blackbox" && service.blackbox ? "name" then
        service.blackbox.name
      else
        service.name
    };internal") caddified_services_list;

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
    #     caddified_services_list);

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
        replacement = "127.0.0.1:9115";
      }
    ];

  };

  nixOS_nodes = (filterAttrs (n: v: v.isNixOS) catalog.nodes);
  nixOS_nodes_list =
    map (node_name: nixOS_nodes."${node_name}" // { name = node_name; })
    (attrNames nixOS_nodes);

  promtail_targets = map (node:
    "${node.name}.joannet.casa:${toString catalog.services.promtail.port}")
    nixOS_nodes_list;

in [
  {
    job_name = "prometheus";
    scrape_interval = "5s";
    static_configs = [{
      targets = [ "localhost:${toString config.services.prometheus.port}" ];
    }];
  }
  {
    job_name = "grafana";
    scrape_interval = "5s";
    static_configs =
      [{ targets = [ "localhost:${toString config.services.grafana.port}" ]; }];
  }
  {
    job_name = "node";
    scrape_interval = "5s";
    static_configs = [{
      targets = map (node:
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
        "dee.joannet.casa:${
          toString config.services.prometheus.exporters.unifi-poller.port
        }"
      ];
    }];
  }
  # {
  #   job_name = "caddy";
  #   static_configs = [{ targets = [ "dee.joannet.casa:2019" ]; }];
  # }
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
    params = { module = [ "http_2xx" ]; };
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
    static_configs = [{ targets = [ "minio.svc.joannet.casa" ]; }];
  }
  {
    job_name = "pve";
    metrics_path = "/pve";
    params.module = [ "default" ];
    static_configs = [{ targets = [ "pve0.joannet.casa:9221" ]; }];
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
]