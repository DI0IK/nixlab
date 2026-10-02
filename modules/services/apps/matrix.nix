{ config, lib, ... }:

{
  services.matrix-continuwuity = {
    enable = true;

    settings.global = {
      server_name = "dominikstahl.dev";
      address = [ "127.0.0.1" ];
      port = [ 6167 ];

      allow_registration = false;
      allow_federation = true;

      well_known = {
        client = "https://matrix.dominikstahl.dev";
        server = "matrix.dominikstahl.dev:443";
      };

      media.retention = [
        {
          scope = "remote";
          created = "30d";
          space = "10G";
        }
      ];

      oauth.oidc = {
        enable = true;
        client_id = "ieNHW82JJboIQr1zdsEKoMi3pTxgIwneNdgkpWnD";
        discovery_url = "https://sso.dominikstahl.dev/application/o/matrix/";
        client_secret_file = config.sops.secrets."matrix-oidc-secret".path;
      };
    };
  };

  # Disable DynamicUser so the service runs consistently as the static continuwuity user/group,
  # matching sops-nix file ownership and persistent storage permissions.
  systemd.services.continuwuity = {
    after = [ "sops-nix.service" ];
    serviceConfig = {
      DynamicUser = lib.mkForce false;
    };
  };

  # Impermanence persistence for Matrix state and media database
  environment.persistence."/persist" = {
    directories = [
      {
        directory = "/var/lib/continuwuity";
        user = "continuwuity";
        group = "continuwuity";
        mode = "0700";
      }
    ];
  };
}
