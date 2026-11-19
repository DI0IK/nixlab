{ config, ... }:

{
  services.n8n = {
    enable = true;
    openFirewall = false;

    taskRunners.enable = true;

    environment = {
      N8N_LISTEN_ADDRESS = "127.0.0.1";
      N8N_PORT = 5678;
      N8N_HOST = "n8n.${config.networking.domain}";
      N8N_PROTOCOL = "https";
      N8N_EDITOR_BASE_URL = "https://n8n.${config.networking.domain}/";
      WEBHOOK_URL = "https://n8n.${config.networking.domain}/";
      N8N_PROXY_HOPS = 1;
      GENERIC_TIMEZONE = "Europe/Berlin";

      # Centralized PostgreSQL (local TCP trust auth in postgres.nix)
      DB_TYPE = "postgresdb";
      DB_POSTGRESDB_HOST = "127.0.0.1";
      DB_POSTGRESDB_PORT = 5432;
      DB_POSTGRESDB_DATABASE = "n8n";
      DB_POSTGRESDB_USER = "n8n";

      N8N_ENCRYPTION_KEY_FILE = config.sops.secrets."n8n-encryption-key".path;
      N8N_RUNNERS_AUTH_TOKEN_FILE = config.sops.secrets."n8n-runners-auth-token".path;
    };
  };

  systemd.services.n8n = {
    after = [ "postgresql.service" ];
    requires = [ "postgresql.service" ];
  };

  # Impermanence: StateDirectory is /var/lib/private/n8n (systemd DynamicUser)
  environment.persistence."/persist" = {
    directories = [
      "/var/lib/private/n8n"
    ];
  };
}
