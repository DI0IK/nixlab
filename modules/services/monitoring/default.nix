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

    retentionTime = "1y";
    extraFlags = [
      "--storage.tsdb.retention.size=25GB"
    ];

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
        extraFlags = [
          "--collector.filesystem.mount-points-exclude=^/mnt/immich-external-old-nas$"
        ];
      };
      redis = {
        enable = true;
        port = 9121;
        listenAddress = "127.0.0.1";
      };
      postgres = {
        enable = true;
        port = 9187;
        listenAddress = "127.0.0.1";
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
      {
        job_name = "local-redis";
        static_configs = [
          {
            targets = [
              "127.0.0.1:${toString config.services.prometheus.exporters.redis.port}"
            ];
          }
        ];
      }
      {
        job_name = "local-postgres";
        static_configs = [
          {
            targets = [
              "127.0.0.1:${toString config.services.prometheus.exporters.postgres.port}"
            ];
          }
        ];
      }
      {
        job_name = "local-traefik";
        metrics_path = "/metrics";
        static_configs = [
          {
            targets = [ "127.0.0.1:9101" ];
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
    configuration = {
      auth_enabled = false;
      server.http_listen_port = 3100;

      # Explicitly run as a single monolithic process
      target = "all";

      common = {
        path_prefix = "/var/lib/loki";
        replication_factor = 1;
        ring = {
          instance_addr = "127.0.0.1";
          kvstore.store = "inmemory";
        };
        storage.filesystem = {
          chunks_directory = "/var/lib/loki/chunks";
          rules_directory = "/var/lib/loki/rules";
        };
      };

      ingester = {
        lifecycler = {
          address = "127.0.0.1";
          ring = {
            kvstore.store = "inmemory";
            replication_factor = 1;
          };
          num_tokens = 512;
        };
      };

      limits_config = {
        volume_enabled = true;
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
    };
  };

  # Grafana Alloy replaces end-of-life Promtail for systemd-journal log scraping
  services.alloy = {
    enable = true;
    configPath = pkgs.writeText "config.alloy" ''
      loki.relabel "journal" {
        // forward_to is strictly required by Alloy component validation
        forward_to = []

        // 1. Raw systemd unit
        rule {
          source_labels = ["__journal__systemd_unit"]
          target_label  = "unit"
        }

        // 2. Base service_name: strip .service suffix
        rule {
          source_labels = ["__journal__systemd_unit"]
          regex         = "(.+)\\.service"
          target_label  = "service_name"
        }

        // 3. Container override: extract container name for podman units
        rule {
          source_labels = ["__journal__systemd_unit"]
          regex         = "podman-(.+)\\.service"
          target_label  = "service_name"
        }

        // 4. Fallback service_name: syslog identifier or process name
        // (.* at the end allows matching when subsequent source_labels are present)
        rule {
          source_labels = ["service_name", "__journal_syslog_identifier", "__journal__comm"]
          regex         = "^;*([^;]+).*"
          target_label  = "service_name"
        }

        // 5. Explicitly map 'app' for dashboards requiring the app label
        rule {
          source_labels = ["service_name"]
          regex         = "(.+)"
          target_label  = "app"
        }
      }

      loki.source.journal "read" {
        forward_to    = [loki.write.local.receiver]
        relabel_rules = loki.relabel.journal.rules
        labels        = {
          job  = "systemd-journal",
          host = "${config.networking.hostName}",
        }
        max_age       = "12h"
        path          = "/var/log/journal"
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

      users = {
        allow_sign_up = false;
      };

      auth = {
        disable_login_form = true;
      };

      "auth.basic" = {
        enabled = false;
      };

      security = {
        secret_key = "$__file{${config.sops.secrets."grafana-secret-key".path}}";
      };

      "auth.generic_oauth" = {
        enabled = true;
        allow_sign_up = true;
        auto_login = true;
        name = "Authentik";
        icon = "signin";
        client_id = "nAD3LK27pHMU6QcWctCfY5lgR7vH3QmL2zdyE6ng";
        client_secret = "$__file{${config.sops.secrets."grafana-oauth-client-secret".path}}";
        scopes = "openid profile email offline_access";
        auth_url = "https://sso.${config.networking.domain}/application/o/authorize/";
        token_url = "https://sso.${config.networking.domain}/application/o/token/";
        api_url = "https://sso.${config.networking.domain}/application/o/userinfo/";
        use_pkce = true;
        use_refresh_token = false;

        # Role mapping based on Authentik groups:
        # - "Grafana Admins" -> GrafanaAdmin
        # - "Grafana" -> Editor
        # - fallback -> Viewer
        role_attribute_path = "contains(groups, 'Grafana Admins') && 'GrafanaAdmin' || contains(groups, 'Grafana') && 'Editor' || 'Viewer'";
        allow_assign_grafana_admin = true;
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
      "/var/lib/private/alloy"
      "/var/lib/grafana"
    ];
  };
}
