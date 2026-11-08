{ config, pkgs, ... }:

{
  services.kavita = {
    enable = true;
    settings = {
      Port = 5000;
      IpAddresses = "127.0.0.1";
      TokenKey = "@token_key@";
      OpenIdConnectSettings = {
        Authority = "https://sso.dominikstahl.dev/application/o/kavita/";
        ClientId = "kavita";
        Secret = "@oidc_client_secret@";
        CustomScopes = [ ];
        Enabled = true;
      };
    };
    credentials = {
      token_key = "/persist/var/lib/kavita/token_key";
      oidc_client_secret = config.sops.secrets."kavita-oidc-client-secret".path;
    };
  };

  # Automatically initialize a 512-bit TokenKey file on persistent storage if missing
  systemd.services.kavita-init-key = {
    description = "Generate Kavita token key if missing";
    wantedBy = [ "kavita.service" ];
    before = [ "kavita.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      mkdir -p /persist/var/lib/kavita
      if [ ! -f /persist/var/lib/kavita/token_key ]; then
        ${pkgs.coreutils}/bin/head -c 64 /dev/urandom | ${pkgs.coreutils}/bin/base64 -w0 > /persist/var/lib/kavita/token_key
        chmod 600 /persist/var/lib/kavita/token_key
        chown kavita:kavita /persist/var/lib/kavita/token_key
      fi
    '';
  };

  # Access shared NFS media storage
  users.users.kavita.extraGroups = [ "media" ];

  # Order service startup after NFS media share is mounted
  systemd.services.kavita = {
    after = [ "data-media.mount" ];
    wants = [ "data-media.mount" ];
  };

  # Impermanence persistence for Kavita database, config, covers, and cache
  environment.persistence."/persist" = {
    directories = [
      {
        directory = "/var/lib/kavita";
        user = "kavita";
        group = "kavita";
        mode = "0750";
      }
    ];
  };
}
