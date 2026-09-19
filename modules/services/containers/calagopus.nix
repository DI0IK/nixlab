{ pkgs, ... }:

{
  # Ensure persistent state directories exist
  systemd.tmpfiles.rules = [
    "d /persist/var/lib/calagopus 0750 root root -"
    "d /persist/var/log/calagopus 0750 root root -"
  ];

  # Generate initial APP_ENCRYPTION_KEY if not already created
  systemd.services.podman-calagopus-pre = {
    description = "Initialize Calagopus Panel Environment";
    wantedBy = [ "podman-calagopus.service" ];
    before = [ "podman-calagopus.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = pkgs.writeShellScript "init-calagopus-env" ''
        mkdir -p /persist/var/lib/calagopus /persist/var/log/calagopus
        ENV_FILE="/persist/var/lib/calagopus/calagopus.env"
        if [ ! -f "$ENV_FILE" ]; then
          KEY=$(tr -dc 'a-zA-Z0-9' < /dev/urandom | head -c 32)
          echo "APP_ENCRYPTION_KEY=$KEY" > "$ENV_FILE"
          chmod 0600 "$ENV_FILE"
        fi
      '';
    };
  };

  # Calagopus Game Server Management Panel
  virtualisation.oci-containers.containers.calagopus = {
    image = "ghcr.io/calagopus/panel:latest";
    autoStart = true;
    extraOptions = [
      "--network=host"
    ];
    environment = {
      TZ = "Europe/Berlin";
      APP_URL = "https://panel.dominikstahl.dev";
      APP_ENV = "production";
      PORT = "8008";
      DATABASE_URL = "postgresql://calagopus@127.0.0.1:5432/calagopus";
      DATABASE_MIGRATE = "true";
      REDIS_URL = "redis://127.0.0.1:6379";
      APP_PRIMARY = "true";
      APP_ENABLE_WINGS_PROXY = "true";
      APP_USE_DECRYPTION_CACHE = "true";
      APP_DEBUG = "false";
      APP_LOG_DIRECTORY = "/var/log/calagopus";
    };
    environmentFiles = [
      "/persist/var/lib/calagopus/calagopus.env"
    ];
    volumes = [
      "/persist/var/lib/calagopus:/var/lib/calagopus"
      "/persist/var/log/calagopus:/var/log/calagopus"
    ];
  };

  # Ensure database and cache services are ready before starting the panel
  systemd.services.podman-calagopus = {
    after = [
      "postgresql.service"
      "redis-default.service"
      "podman-calagopus-pre.service"
    ];
    wants = [
      "postgresql.service"
      "redis-default.service"
      "podman-calagopus-pre.service"
    ];
  };

  # Impermanence persistence for Calagopus Panel
  environment.persistence."/persist" = {
    directories = [
      "/var/lib/calagopus"
      "/var/log/calagopus"
    ];
  };
}
