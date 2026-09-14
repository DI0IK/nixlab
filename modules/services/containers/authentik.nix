{ config, ... }:

{
  virtualisation.oci-containers.containers = {
    authentik-server = {
      image = "ghcr.io/goauthentik/server:2026.8.2";
      autoStart = true;
      cmd = [ "server" ];
      extraOptions = [
        "--network=host"
        "--shm-size=512m"
      ];
      environment = {
        AUTHENTIK_REDIS__HOST = "127.0.0.1";
        AUTHENTIK_REDIS__PORT = "6379";
        AUTHENTIK_REDIS__DB = "1";
        AUTHENTIK_POSTGRESQL__HOST = "127.0.0.1";
        AUTHENTIK_POSTGRESQL__USER = "authentik";
        AUTHENTIK_POSTGRESQL__NAME = "authentik";
        AUTHENTIK_POSTGRESQL__PORT = "5432";
        AUTHENTIK_LISTEN__HTTP = "127.0.0.1:9000";
        AUTHENTIK_LISTEN__HTTPS = "127.0.0.1:9443";
      };
      environmentFiles = [
        config.sops.templates."authentik.env".path
      ];
      volumes = [
        "/persist/var/lib/authentik/media:/media"
        "/persist/var/lib/authentik/custom-templates:/templates"
      ];
    };

    authentik-worker = {
      image = "ghcr.io/goauthentik/server:2026.8.2";
      autoStart = true;
      user = "0";
      cmd = [ "worker" ];
      extraOptions = [
        "--network=host"
        "--shm-size=512m"
      ];
      environment = {
        AUTHENTIK_REDIS__HOST = "127.0.0.1";
        AUTHENTIK_REDIS__PORT = "6379";
        AUTHENTIK_REDIS__DB = "1";
        AUTHENTIK_POSTGRESQL__HOST = "127.0.0.1";
        AUTHENTIK_POSTGRESQL__USER = "authentik";
        AUTHENTIK_POSTGRESQL__NAME = "authentik";
        AUTHENTIK_POSTGRESQL__PORT = "5432";
      };
      environmentFiles = [
        config.sops.templates."authentik.env".path
      ];
      volumes = [
        "/persist/var/lib/authentik/media:/media"
        "/persist/var/lib/authentik/custom-templates:/templates"
        "/var/run/podman/podman.sock:/var/run/docker.sock"
      ];
    };

    authentik-ldap = {
      image = "ghcr.io/goauthentik/ldap:2026.8.2";
      autoStart = true;
      user = "0";
      extraOptions = [
        "--network=host"
      ];
      environment = {
        AUTHENTIK_HOST = "http://127.0.0.1:9000";
        AUTHENTIK_INSECURE = "true";
        AUTHENTIK_LISTEN__LDAP = "0.0.0.0:389";
        AUTHENTIK_LISTEN__LDAPS = "0.0.0.0:636";
        AUTHENTIK_LISTEN__METRICS = "0.0.0.0:9301";
      };
      environmentFiles = [
        config.sops.templates."authentik-ldap.env".path
      ];
    };
  };

  # Impermanence persistence for Authentik media and blueprints
  environment.persistence."/persist" = {
    directories = [
      "/var/lib/authentik"
    ];
  };
}
