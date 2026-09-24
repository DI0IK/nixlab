{ ... }:

{
  services.n8n = {
    enable = true;
    openFirewall = false;

    environment = {
      GENERIC_TIMEZONE = "Europe/Berlin";
      N8N_HOST = "n8n.dominikstahl.dev";
      N8N_PORT = "5678";
      N8N_LISTEN_ADDRESS = "127.0.0.1";
      N8N_PROTOCOL = "https";
      WEBHOOK_URL = "https://n8n.dominikstahl.dev/";

      # Database: Centralized PostgreSQL
      DB_TYPE = "postgresdb";
      DB_POSTGRESDB_HOST = "127.0.0.1";
      DB_POSTGRESDB_PORT = "5432";
      DB_POSTGRESDB_DATABASE = "n8n";
      DB_POSTGRESDB_USER = "n8n";

      # Telemetry & Diagnostics
      N8N_DIAGNOSTICS_ENABLED = "false";
      N8N_VERSION_NOTIFICATIONS_ENABLED = "false";
      N8N_METRICS = "true";
      N8N_METRICS_PREFIX = "n8n_";
    };
  };

  # Impermanence: StateDirectory is /var/lib/private/n8n (managed by systemd DynamicUser)
  environment.persistence."/persist" = {
    directories = [
      "/var/lib/private/n8n"
    ];
  };
}
