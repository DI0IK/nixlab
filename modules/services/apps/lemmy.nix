{ config, lib, ... }:

{
  services.lemmy = {
    enable = true;
    settings = {
      hostname = "lemmy.dominikstahl.dev";
      bind = "127.0.0.1";
      port = 8536;
      tls_enabled = true;

      oauth = {
        provider = "authentik";
        client_id = "cRGsHFYPxNHtAhYkfpW2XUyBUz9WqNvOa5xdvPTd";
        auth_url = "https://sso.dominikstahl.dev/application/o/authorize/";
        token_url = "https://sso.dominikstahl.dev/application/o/token/";
        user_info_url = "https://sso.dominikstahl.dev/application/o/userinfo/";
        scopes = [
          "openid"
          "profile"
          "email"
        ];
        id_field = "sub";
        username_field = "preferred_username";
        email_field = "email";
      };
    };

    ui = {
      port = 8537;
    };

    database = {
      createLocally = false;
      uri = "postgres:///lemmy?host=/run/postgresql&user=lemmy";
    };
  };

  # Inject decrypted Lemmy OIDC client secret via EnvironmentFile
  systemd.services.lemmy = {
    after = [
      "sops-nix.service"
      "postgresql.service"
    ];
    requires = [ "postgresql.service" ];
    serviceConfig = {
      EnvironmentFile = [
        config.sops.templates."lemmy.env".path
      ];
    };
  };

  # Inform lemmy-ui that it is being accessed externally through an HTTPS reverse proxy
  systemd.services.lemmy-ui.environment.LEMMY_UI_HTTPS = lib.mkForce "true";

  # Impermanence persistence for pict-rs media storage (managed by systemd DynamicUser)
  environment.persistence."/persist" = {
    directories = [
      "/var/lib/private/pict-rs"
    ];
  };
}
