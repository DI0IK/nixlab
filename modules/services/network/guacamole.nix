{ config, pkgs, ... }:

{
  services.guacamole-server = {
    enable = true;
    host = "0.0.0.0";
    port = 4822;
  };

  fonts.packages = with pkgs; [
    dejavu_fonts
    liberation_ttf
    noto-fonts
  ];

  fonts.fontDir.enable = true;

  virtualisation.oci-containers.containers.guacamole-client = {
    image = "docker.io/guacamole/guacamole:1.6.0";
    ports = [ "8084:8080" ];

    extraOptions = [
      "--network=bridge"
      "--add-host=host.docker.internal:host-gateway"
    ];

    environment = {
      GUACD_HOSTNAME = "host.docker.internal";
      GUACD_PORT = "4822";

      POSTGRESQL_HOSTNAME = "host.docker.internal";
      POSTGRESQL_PORT = "5432";
      POSTGRESQL_DATABASE = "guacamole";
      POSTGRESQL_USER = "guacamole";
      POSTGRESQL_PASSWORD = "password";

      OPENID_AUTHORIZATION_ENDPOINT = "https://sso.dominikstahl.dev/application/o/authorize/";
      OPENID_JWKS_ENDPOINT = "https://sso.dominikstahl.dev/application/o/guacamole/jwks/";
      OPENID_ISSUER = "https://sso.dominikstahl.dev/application/o/guacamole/";
      OPENID_CLIENT_ID = "bdSzU7xIotTTI0QPHf2vYRNQxNDq0ABS2cMC9fM9";
      OPENID_REDIRECT_URI = "https://guacamole.dominikstahl.dev/guacamole/";
      OPENID_ALLOWED_CLOCK_SKEW = "60";

      EXTENSION_PRIORITY = "openid, jdbc";
    };
  };
}
