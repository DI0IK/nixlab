{ config, ... }:

{
  # Kernel tuning for Elasticsearch
  boot.kernel.sysctl = {
    "vm.max_map_count" = 262144;
  };

  # Declaratively ensure persistent directories exist with proper container ownership
  systemd.tmpfiles.rules = [
    "d /persist/var/lib/tubearchivist 0750 root root -"
    "d /persist/var/lib/tubearchivist/cache 0775 1000 1000 -"
    "d /persist/var/lib/tubearchivist/es 0775 1000 0 -"
  ];

  virtualisation.oci-containers.containers = {
    # Elasticsearch backend for Tube Archivist indexing and search
    archivist-es = {
      image = "docker.io/bbilly1/tubearchivist-es:latest";
      autoStart = true;
      extraOptions = [
        "--network=host"
      ];
      environment = {
        "ELASTIC_PASSWORD" = "tubearchivist-elastic-internal";
        "ES_JAVA_OPTS" = "-Xms1g -Xmx1g";
        "xpack.security.enabled" = "true";
        "discovery.type" = "single-node";
        "path.repo" = "/usr/share/elasticsearch/data/snapshot";
        "network.host" = "127.0.0.1";
        "http.port" = "9200";
        "transport.port" = "9350";
      };
      volumes = [
        "/persist/var/lib/tubearchivist/es:/usr/share/elasticsearch/data"
      ];
    };

    # Tube Archivist main web application
    tubearchivist = {
      image = "docker.io/bbilly1/tubearchivist:latest";
      autoStart = true;
      extraOptions = [
        "--network=host"
      ];
      environment = {
        TA_USERNAME = "tubearchivist";
        ELASTIC_PASSWORD = "tubearchivist-elastic-internal";
        ES_URL = "http://127.0.0.1:9200";
        REDIS_CON = "redis://127.0.0.1:6379/2";
        REDIS_NAME_SPACE = "ta:";
        TA_HOST = "https://tubearchivist.dominikstahl.dev";
        TA_PORT = "8005";
        TA_BACKEND_PORT = "8006";
        TZ = "Europe/Berlin";
      };
      environmentFiles = [
        config.sops.templates."tubearchivist.env".path
      ];
      volumes = [
        "/data/media/media/youtube:/youtube"
        "/persist/var/lib/tubearchivist/cache:/cache"
      ];
    };
  };

  # Service order dependencies
  systemd.services.podman-tubearchivist = {
    after = [
      "podman-archivist-es.service"
      "redis-default.service"
      "data-media.mount"
    ];
    wants = [
      "podman-archivist-es.service"
      "redis-default.service"
      "data-media.mount"
    ];
  };

  # Impermanence persistence for Tube Archivist state and caches
  environment.persistence."/persist" = {
    directories = [
      "/var/lib/tubearchivist"
    ];
  };
}
