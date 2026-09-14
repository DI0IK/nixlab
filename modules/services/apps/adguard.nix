{ config, lib, pkgs, ... }:

{
  users.users.adguardhome = {
    isSystemUser = true;
    group = "adguardhome";
    home = "/var/lib/AdGuardHome";
  };
  users.groups.adguardhome = { };

  services.adguardhome = {
    enable = true;
    host = "127.0.0.1";
    port = 3001;
    mutableSettings = true;

    settings = {
      http = {
        address = "127.0.0.1:3001";
      };
      dns = {
        bind_hosts = [
          "127.0.0.1"
          "192.168.178.110"
          "172.30.32.2"
          "::1"
        ];
        port = 53;
      };
      tls = {
        enabled = true;
        server_name = "dns.dominikstahl.dev";
        port_https = 0;
        port_dns_over_tls = 853;
        port_dns_over_quic = 853;
        certificate_path = "/var/lib/acme/dominikstahl.dev/fullchain.pem";
        private_key_path = "/var/lib/acme/dominikstahl.dev/key.pem";
      };
    };
  };

  systemd.services.adguardhome = {
    serviceConfig = {
      DynamicUser = lib.mkForce false;
      User = "adguardhome";
      Group = "adguardhome";
    };
    # Wait for initial certificate issuance on first boot
    wants = [ "acme-dominikstahl.dev.service" ];
    after = [ "acme-dominikstahl.dev.service" ];
  };

  # Impermanence persistence for AdGuard Home configuration and filter query logs
  environment.persistence."/persist" = {
    directories = [
      "/var/lib/AdGuardHome"
    ];
  };
}


