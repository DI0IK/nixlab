{ config, ... }:

{
  services.mealie = {
    enable = true;
    listenAddress = "127.0.0.1";
    port = 9002;
    openFirewall = false;
    credentialsFile = config.sops.templates."mealie.env".path;

    settings = {
      BASE_URL = "https://mealie.dominikstahl.dev";

      # Centralized PostgreSQL
      DB_ENGINE = "postgres";
      POSTGRES_SERVER = "127.0.0.1";
      POSTGRES_PORT = 5432;
      POSTGRES_DB = "mealie";
      POSTGRES_USER = "mealie";

      # Disable local signups and password login (OIDC-only)
      ALLOW_SIGNUP = "false";
      ALLOW_PASSWORD_LOGIN = "false";

      # OpenID Connect (Authentik SSO)
      OIDC_AUTH_ENABLED = "true";
      OIDC_SIGNUP_ENABLED = "true";
      OIDC_PROVIDER_NAME = "Authentik";
      OIDC_CONFIGURATION_URL = "https://sso.dominikstahl.dev/application/o/mealie/.well-known/openid-configuration";
      OIDC_CLIENT_ID = "cK5babGmnWHg1TU4Ydl17GXp3YaSUWcRJlz4Pj32";
      OIDC_REQUIRES_EMAIL_VERIFICATION = "false";
      OIDC_ADMIN_GROUP = "Mealie Admin";
      OIDC_GROUPS_CLAIM = "groups";
      OIDC_AUTO_REDIRECT = "true";
      OIDC_REMEMBER_ME = "true";
    };
  };

  # Impermanence: StateDirectory is /var/lib/private/mealie (managed by systemd DynamicUser)
  environment.persistence."/persist" = {
    directories = [
      "/var/lib/private/mealie"
    ];
  };
}
