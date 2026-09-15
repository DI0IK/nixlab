{ config, pkgs, ... }:

{
  services.searx = {
    enable = true;
    redisCreateLocally = false;
    environmentFile = config.sops.templates."searxng.env".path;

    settings = {
      server = {
        secret_key = "$SEARX_SECRET_KEY";
        bind_address = "127.0.0.1";
        port = 8888;
        base_url = "https://search.dominikstahl.dev/";
      };
      ui = {
        default_theme = "simple";
        infinite_scroll = true;
      };
      search = {
        safe_search = 0;
        autocomplete = "duckduckgo";
      };
    };
  };

  # Impermanence persistence for SearXNG
  environment.persistence."/persist" = {
    directories = [
      "/var/lib/searx"
    ];
  };
}
