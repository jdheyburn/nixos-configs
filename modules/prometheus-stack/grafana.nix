{ catalog, config, pkgs, lib, ... }:

with lib;

let cfg = config.modules.prometheusStack;
in {
  options.modules.prometheusStack.grafana.enable = mkEnableOption "Deploy Grafana";

  config = mkIf (cfg.enable && cfg.grafana.enable) {

    age.secrets."grafana-admin-password" = {
      file = ../../../secrets/grafana-admin-password.age;
      owner = "grafana";
      group = "grafana";
    };
    age.secrets."smtp-password" = {
      file = ../../../secrets/smtp-password.age;
      owner = "grafana";
      group = "grafana";
    };

    services.caddy.virtualHosts."grafana.${catalog.domain.service}".extraConfig = ''
      tls {
        dns cloudflare {env.CLOUDFLARE_API_TOKEN}
        # Below required to get TLS to work on non-local hosts (i.e. charlie)
        resolvers 1.1.1.1
      }
      reverse_proxy localhost:${toString catalog.services.grafana.port}
    '';

    services.grafana = {
      enable = true;

      settings = {
        analytics.reporting_enabled = false;

        database.wal = true;

        server = {
          root_url = "https://grafana.${catalog.domain.service}";
          http_addr = "0.0.0.0";
          http_port = catalog.services.grafana.port;
          enable_gzip = true;
        };

        security = {
          admin_password = "$__file{${config.age.secrets."grafana-admin-password".path}}";
        };

        smtp = {
          enabled = true;
          host = "smtp.gmail.com:587";
          user = "jdheyburn@gmail.com";
          password = "$__file{${config.age.secrets."smtp-password".path}}";
        };
      };

      declarativePlugins = with pkgs.grafanaPlugins; [ grafana-piechart-panel ];

      provision = {
        enable = true;
        alerting = {
          contactPoints.settings = {
            # Rremove the default contact point
            deleteContactPoints = [{
              orgId = 1;
              uid = "";
            }];

            contactPoints = [
              {
                name = "email-me";
                receivers = [{
                  uid = "email-me";
                  type = "email";
                  settings = {
                    addresses = "jdheyburn@gmail.com";
                  };
                }];
              }
              {
                name = "email-me-no-resolve";
                receivers = [{
                  uid = "email-me-no-resolve";
                  type = "email";
                  disableResolveMessage = true;
                  settings = {
                    addresses = "jdheyburn@gmail.com";
                  };
                }];
              }
            ];
          };

          rules.settings = {
            groups = [{
              name = "internal";
              folder = "homelab";
              interval = "1m";
              rules = [
                # Internal services are down
                {
                  uid = "internal-service-are-down";
                  title = "Internal services are down";
                  condition = "C";
                  dashboardUid = "pS6ZuGV7z";
                  panelId = "2";
                  noDataState = "OK";
                  execErrState = "OK";
                  for = "5m";
                  annotations.description = "{{ $labels.humanname }} is down";
                  annotations.summary = "{{ $labels.humanname }} is down";
                  labels.resolvable = "true";

                  data = [
                    {
                      refId = "A";
                      datasourceUid = "victoria-metrics";
                      relativeTimeRange.from = 300;
                      relativeTimeRange.to = 0;
                      model = {
                        refId = "A";
                        expr = "max by(humanname) (probe_success{routing=\"internal\"})";
                        intervalMs = 1000;
                        maxDataPoints = 43200;
                        hide = false;
                        range = true;
                      };
                    }
                    {
                      refId = "B";
                      datasourceUid = "-100";
                      model = {
                        conditions = [{
                          evaluator.params = [ 1 ];
                          evaluator.type = "lt";
                          operator.type = "and";
                          query.params = [ "A" ];
                          reducer.params = [ ];
                          reducer.type = "max";
                          type = "query";
                        }];
                        datasource.type = "__expr__";
                        datasource.uid = "-100";
                        expression = "A";
                        hide = false;
                        intervalMs = 1000;
                        maxDataPoints = 43200;
                        reducer = "max";
                        refId = "B";
                        settings.mode = "dropNN";
                        type = "reduce";
                      };
                    }
                    {
                      refId = "C";
                      datasourceUid = "-100";
                      model = {
                        conditions = [{
                          evaluator.params = [ 0 0 ];
                          evaluator.type = "gt";
                          operator.type = "and";
                          query.params = [ ];
                          reducer.params = [ ];
                          reducer.type = "avg";
                          type = "query";
                        }];
                        datasource.name = "Expression";
                        datasource.type = "__expr__";
                        datasource.uid = "__expr__";
                        expression = "$B < 1";
                        hide = false;
                        intervalMs = 1000;
                        maxDataPoints = 43200;
                        refId = "C";
                        type = "math";
                      };
                    }
                  ];
                }
                # Job failed
                {
                  uid = "job-failed";
                  title = "Job failed";
                  condition = "C";
                  noDataState = "OK";
                  execErrState = "OK";
                  for = "1m";
                  annotations.description = "{{ $labels.service }} failed on {{ $labels.host }} with reason: {{ $labels.result }}";
                  annotations.summary = "Job {{ $labels.service }} failed";
                  labels.resolvable = "false";
                  isPaused = false;
                  data = [
                    {
                      refId = "A";
                      datasourceUid = "loki";
                      queryType = "range";
                      relativeTimeRange.from = 300;
                      relativeTimeRange.to = 0;
                      model = {
                        refId = "A";
                        expr = "count_over_time({host=~\".+\", unit!~\"(loki|grafana).service\"} |= \"Failed with result\" | regexp \"(?P<service>.*): Failed with result ''(?P<result>.*)''.\" [5m])";
                        hide = false;
                        interval = 1000;
                        maxDataPoints = 43200;
                        queryType = "range";
                      };
                    }
                    {
                      refId = "B";
                      datasourceUid = "-100";
                      model = {
                        conditions = [{
                          evaluator.params = [ 0 0 ];
                          evaluator.type = "gt";
                          operator.type = "and";
                          query.params = [ ];
                          reducer.params = [ ];
                          reducer.type = "avg";
                          type = "query";
                        }];
                        datasource.name = "Expression";
                        datasource.type = "__expr__";
                        datasource.uid = "__expr__";
                        expression = "A";
                        hide = false;
                        intervalMs = 1000;
                        maxDataPoints = 43200;
                        reducer = "max";
                        refId = "B";
                        settings.mode = "dropNN";
                        type = "reduce";
                      };
                    }
                    {
                      refId = "C";
                      datasourceUid = "-100";
                      model = {
                        conditions = [{
                          evaluator.params = [ 0 0 ];
                          evaluator.type = "gt";
                          operator.type = "and";
                          query.params = [ ];
                          reducer.params = [ ];
                          reducer.type = "avg";
                          type = "query";
                        }];
                        datasource.name = "Expression";
                        datasource.type = "__expr__";
                        datasource.uid = "__expr__";
                        expression = "$B > 0";
                        hide = false;
                        intervalMs = 1000;
                        maxDataPoints = 43200;
                        refId = "C";
                        type = "math";
                      };
                    }
                  ];
                }
              ];
            }];
          };

          policies.settings = {
            policies = [
              {
                receiver = "email-me";
                group_by = [ "..." ];
                group_wait = "60s";
                group_interval = "5m";
                repeat_interval = "4h";
                routes = [
                  {
                    receiver = "email-me-no-resolve";
                    matchers = [ "resolvable = false" ];
                  }
                ];
              }
            ];
          };
        };

        datasources.settings = {
          datasources = [
            {
              uid = "victoria-metrics";
              name = "VictoriaMetrics";
              type = "prometheus";
              url =
                "http://localhost:${toString catalog.services.victoriametrics.port}";
              isDefault = true;
              jsonData = {
                timeInterval = "5s"; # node is scraping at 5s
              };
            }
            {
              uid = "loki";
              name = "Loki";
              type = "loki";
              url = "http://localhost:${
                      toString config.services.loki.configuration.server.http_listen_port
                    }";
            }
          ];
        };
      };

    };

    # Since upgrading Grafana to 9.4 there are panics that occur at 00:11 UTC
    # Adding some retry logic on failure
    systemd.services.grafana = {
      serviceConfig = {
        Restart = "on-failure";
        RestartSec = "10s";
      };

      unitConfig = {
        StartLimitIntervalSec = "500";
        StartLimitBurst = "5";
      };
    };

    services.restic.backups.small-files = {
      paths = [ config.services.grafana.dataDir ];
    };
  };
}

