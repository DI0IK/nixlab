{ config, pkgs, ... }:

{
  security.acme = {
    acceptTerms = true;
    defaults.email = "admin@dominikstahl.dev";

    certs."dominikstahl.dev" = {
      domain = "dominikstahl.dev";
      extraDomainNames = [
        "*.dominikstahl.dev"
        "*.dns.dominikstahl.dev"
      ];
      dnsProvider = "cloudflare";
      environmentFile = config.sops.templates."acme-cf.env".path;
      group = "certs";
      reloadServices = [
        "traefik.service"
        "adguardhome.service"
      ];
    };
  };

  # Group to allow authorized services read access to certificates
  users.groups.certs = { };

  # Add Traefik and AdGuard Home to certs group
  users.users.traefik.extraGroups = [ "certs" ];
  users.users.adguardhome.extraGroups = [ "certs" ];

  # Impermanence: persist ACME account keys and certificates
  environment.persistence."/persist" = {
    directories = [
      "/var/lib/acme"
    ];
  };
}
