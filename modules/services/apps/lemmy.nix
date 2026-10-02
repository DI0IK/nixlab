{ config, lib, pkgs, ... }:

let
  lemmyConfig = pkgs.writeText "lemmy.hjson" (builtins.toJSON {
    hostname = "lemmy.dominikstahl.dev";
    bind = "0.0.0.0";
    port = 8536;
    tls_enabled = true;
    pictrs = {
      url = "http://127.0.0.1:8538";
    };
    database = {
      connection = "postgres://lemmy@127.0.0.1:5432/lemmy";
      pool_size = 10;
    };
  });
in
{
  virtualisation.oci-containers.containers = {
    lemmy = {
      image = "docker.io/dessalines/lemmy:1.0.0-beta.2";
      autoStart = true;
      extraOptions = [
        "--network=host"
      ];
      environment = {
        RUST_LOG = "warn,lemmy_server=info,lemmy_api=info";
        RUST_MIN_STACK = "16777216";
        RUST_BACKTRACE = "1";
        LEMMY_CONFIG_LOCATION = "/config/config.hjson";
        LEMMY_DATABASE_URL = "postgres://lemmy@127.0.0.1:5432/lemmy";
      };
      volumes = [
        "${lemmyConfig}:/config/config.hjson:ro"
      ];
    };

    lemmy-ui = {
      image = "docker.io/dessalines/lemmy-ui:1.0.0-beta.2";
      autoStart = true;
      extraOptions = [
        "--network=host"
      ];
      environment = {
        LEMMY_UI_HOST = "127.0.0.1:8537";
        LEMMY_UI_BACKEND_INTERNAL = "http://127.0.0.1:8536";
        LEMMY_UI_BACKEND = "https://lemmy.dominikstahl.dev";
        LEMMY_UI_HTTPS = "true";
      };
    };
  };

  systemd.services.podman-lemmy = {
    after = [
      "postgresql.service"
      "pict-rs.service"
    ];
    requires = [
      "postgresql.service"
      "pict-rs.service"
    ];
  };

  systemd.services.podman-lemmy-ui = {
    after = [ "podman-lemmy.service" ];
    requires = [ "podman-lemmy.service" ];
  };

  # Configure pict-rs port to 8538 to avoid conflict with sabnzbd on 8080
  services.pict-rs = {
    enable = true;
    port = 8538;
  };

  # Define static user and disable DynamicUser so pict-rs runs reliably
  # with impermanence and stable ownership
  users.users.pict-rs = {
    group = "pict-rs";
    isSystemUser = true;
  };
  users.groups.pict-rs = { };

  systemd.services.pict-rs = {
    environment = {
      PICTRS__CLIENT__TIMEOUT = "15";
      PICTRS__MEDIA__PROCESS_TIMEOUT = "30";
      PICTRS__MEDIA__RETENTION__PROXY = "7d";
      PICTRS__MEDIA__RETENTION__VARIANTS = "7d";
    };
    serviceConfig = {
      DynamicUser = lib.mkForce false;
      User = "pict-rs";
      Group = "pict-rs";
      LimitNOFILE = 65536;
    };
  };

  # Impermanence persistence for pict-rs media storage
  environment.persistence."/persist" = {
    directories = [
      {
        directory = "/var/lib/pict-rs";
        user = "pict-rs";
        group = "pict-rs";
        mode = "0750";
      }
    ];
  };
}
