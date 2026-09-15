{
  config,
  pkgs,
  ...
}:

{
  # ==========================================
  # 1. METRICS (Prometheus & Exporter)
  # ==========================================
  services.prometheus = {
    enable = true;
    port = 9090;
    listenAddress = "127.0.0.1";

    exporters = {
      node = {
        enable = true;
        port = 9100;
        listenAddress = "127.0.0.1";
        enabledCollectors = [
          "systemd"
          "diskstats"
          "cpu"
          "meminfo"
          "netdev"
        ];
      };
    };

    scrapeConfigs = [
      {
        job_name = "local-node";
        static_configs = [
          {
            targets = [
              "127.0.0.1:${toString config.services.prometheus.exporters.node.port}"
            ];
          }
        ];
      }
    ];
  };

  # ==========================================
  # 2. LOGS (Loki & Grafana Alloy)
  # ==========================================
  services.loki = {
    enable = true;
    configFile = pkgs.writeText "loki-local.yaml" (
      builtins.toJSON {
        auth_enabled = false;
        server.http_listen_port = 3100;
        common = {
          path_prefix = "/var/lib/loki";
          replication_factor = 1;
          storage.filesystem = {
            chunks_directory = "/var/lib/loki/chunks";
            rules_directory = "/var/lib/loki/rules";
          };
        };
        schema_config = {
          configs = [
            {
              from = "2020-10-24";
              store = "tsdb";
              object_store = "filesystem";
              schema = "v13";
              index = {
                prefix = "index_";
                period = "24h";
              };
            }
          ];
        };
      }
    );
  };

  # Grafana Alloy replaces end-of-life Promtail for systemd-journal log scraping
  services.alloy = {
    enable = true;
    configPath = pkgs.writeText "config.alloy" ''
      loki.relabel "journal" {
        forward_to = [loki.write.local.receiver]

        rule {
          source_labels = ["__journal__systemd_unit"]
          target_label  = "unit"
        }
        rule {
          source_labels = ["__journal__systemd_unit"]
          regex         = "podman-(.+)\\.service"
          target_label  = "container"
        }
      }

      loki.source.journal "read" {
        forward_to = [loki.relabel.journal.receiver]
        labels     = {
          job  = "systemd-journal",
          host = "${config.networking.hostName}",
        }
        max_age    = "12h"
        path       = "/var/log/journal"
      }

      loki.write "local" {
        endpoint {
          url = "http://127.0.0.1:3100/loki/api/v1/push"
        }
      }
    '';
  };

  # ==========================================
  # 3. VISUALIZATION (Grafana)
  # ==========================================
  services.grafana = {
    enable = true;
    settings = {
      server = {
        http_addr = "127.0.0.1";
        http_port = 3005;
        domain = "grafana.${config.networking.domain}";
        root_url = "https://grafana.${config.networking.domain}/";
      };

      security = {
        secret_key = "SW2YcwTIb9zpOOhoPsMm";
      };

      "auth.proxy" = {
        enabled = true;
        header_name = "X-authentik-username";
        header_property = "username";
        auto_sign_up = true;
      };
    };

    provision = {
      enable = true;

      # Declarative Data Sources
      datasources.settings.datasources = [
        {
          name = "Prometheus";
          type = "prometheus";
          url = "http://127.0.0.1:9090";
          isDefault = true;
        }
        {
          name = "Loki";
          type = "loki";
          url = "http://127.0.0.1:3100";
        }
      ];
    };
  };

  # ==========================================
  # 4. IMPERMANENCE PERSISTENCE
  # ==========================================
  environment.persistence."/persist" = {
    directories = [
      "/var/lib/prometheus2"
      "/var/lib/loki"
      "/var/lib/alloy"
      "/var/lib/grafana"
    ];
  };
}
