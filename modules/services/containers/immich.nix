{ config, ... }:

{
  virtualisation.oci-containers.containers = {
    immich-server = {
      image = "ghcr.io/immich-app/immich-server:release";
      autoStart = true;
      extraOptions = [
        "--network=host"
        "--device=/dev/dri:/dev/dri"
      ];
      environment = {
        DB_HOSTNAME = "127.0.0.1";
        DB_PORT = "5432";
        DB_USERNAME = "immich";
        DB_DATABASE_NAME = "immich";
        REDIS_HOSTNAME = "127.0.0.1";
        REDIS_PORT = "6379";
        REDIS_DBINDEX = "0";
        IMMICH_MACHINE_LEARNING_URL = "http://127.0.0.1:3003";
        IMMICH_PORT = "2283";
        IMMICH_CONFIG_FILE = "/config/immich-config.yaml";
      };
      volumes = [
        "/mnt/immich-library:/usr/src/app/upload"
        "/mnt/immich-external:/external:ro"
        "/mnt/immich-external-manger:/external_manger:ro"
        "/mnt/immich-external-old-nas:/external_old_nas:ro"
        "${config.sops.templates."immich-config.yaml".path}:/config/immich-config.yaml:ro"
        "/etc/localtime:/etc/localtime:ro"
      ];
    };

    immich-machine-learning = {
      image = "ghcr.io/immich-app/immich-machine-learning:release-openvino";
      autoStart = true;
      extraOptions = [
        "--network=host"
        "--device=/dev/dri:/dev/dri"
      ];
      environment = {
        MACHINE_LEARNING_PORT = "3003";
        TRANSFORMERS_CACHE = "/cache";
      };
      volumes = [
        "/persist/var/lib/immich/model-cache:/cache"
      ];
    };
  };

  # Impermanence persistence for Immich ML model cache
  environment.persistence."/persist" = {
    directories = [
      "/var/lib/immich"
    ];
  };
}
