{ ... }:

{
  # Self-hosted ntfy-sh push notification server
  services.ntfy-sh = {
    enable = true;
    settings = {
      base-url = "https://ntfy.dominikstahl.dev";
      listen-http = "127.0.0.1:2586";
      behind-proxy = true;
      auth-default-access = "read-write";
    };
  };

  # Impermanence persistence for ntfy-sh cache and database
  environment.persistence."/persist".directories = [
    "/var/lib/ntfy-sh"
  ];
}
