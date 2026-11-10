{ ... }:

{
  security.acme = {
    acceptTerms = true;
    defaults.email = "admin@dominikstahl.dev";
  };

  # Group to allow authorized services read access to certificates
  users.groups.certs = { };

  # Impermanence: persist ACME account keys and certificates across reboots
  environment.persistence."/persist" = {
    directories = [
      "/var/lib/acme"
    ];
  };
}
