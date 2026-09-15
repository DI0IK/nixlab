{ pkgs, config, ... }:

{
  # ==========================================
  # 1. METRIKEN (Prometheus & Exporter)
  # ==========================================
  services.prometheus = {
    enable = true;
    port = 9090;
    
    exporters = {
      node = {
        enable = true;
        port = 9100;
        enabledCollectors = [ "systemd" "diskstats" "cpu" "meminfo" "netdev" ];
      };
    };

    scrapeConfigs = [
      {
        job_name = "local-node";
        static_configs = [
          { targets = [ "127.0.0.1:${toString config.services.prometheus.exporters.node.port}" ]; }
        ];
      }
    ];
  };

  # ==========================================
  # 2. LOGS (Loki & Promtail)
  # ==========================================
  services.loki = {
    enable = true;
    configFile = pkgs.writeText "loki-local.yaml" (builtins.toJSON {
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
        configs = [{
          from = "2020-10-24";
          store = "tsdb";
          object_store = "filesystem";
          schema = "v13";
          index = { prefix = "index_"; period = "24h"; };
        }];
      };
    });
  };

  services.promtail = {
    enable = true;
    configuration = {
      server = {
        http_listen_port = 28183;
        grpc_listen_port = 0;
      };
      clients = [{ url = "http://127.0.0"; }];
      
      scrape_configs = [{
        job_name = "journal";
        journal = {
          max_age = "12h";
          labels = {
            job = "systemd-journal";
            host = "${config.networking.hostName}";
          };
        };
        relabel_configs = [
          {
            source_labels = [ "__journal__systemd_unit" ];
            target_label = "unit";
          }
          {
            source_labels = [ "__journal__systemd_unit" ];
            regex = "podman-(.+)\\.service";
            target_label = "container";
          }
        ];
      }];
    };
  };

  # ==========================================
  # 3. VISUALISIERUNG & DASHBOARDS (Grafana)
  # ==========================================
  services.grafana = {
    enable = true;
    settings.server = {
      http_addr = "127.0.0.1";
      http_port = 3000;
    };

    provision = {
      enable = true;
      
      # Automatische Datenquellen
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

      # Automatische Dashboards beim Systemstart laden
      dashboards.settings.providers = [
        {
          name = "System Dashboards";
          options.path = pkgs.symlinkJoin {
            name = "grafana-dashboards";
            paths = [
              # 1. Node Exporter Full (ID 1860) von Grafana Labs herunterladen
              (pkgs.fetchurl {
                url = "https://grafana.com";
                sha256 = "sha256-R7dMvT0D99TjV+jZp3ZfTqCg3rYh9qLopLzXlE2J1sk="; # Falls der Hash fehlschlägt, per lib.fakeSha256 aktualisieren
              })
            ];
          };
        }
      ];
    };
  };
}
