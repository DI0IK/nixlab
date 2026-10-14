{ ... }:

{
  # Anubis anti-bot and AI scraper proof-of-work protection
  services.anubis = {
    instances = {
      redlib = {
        enable = true;
        settings = {
          BIND = "127.0.0.1:8901";
          BIND_NETWORK = "tcp";
          TARGET = "http://127.0.0.1:8088";
          METRICS_BIND = "127.0.0.1:8902";
          METRICS_BIND_NETWORK = "tcp";
          DIFFICULTY = 5;
          OG_PASSTHROUGH = true;
          COOKIE_DYNAMIC_DOMAIN = true;
          SERVE_ROBOTS_TXT = true;
        };
      };

      kiwix = {
        enable = true;
        settings = {
          BIND = "127.0.0.1:8903";
          BIND_NETWORK = "tcp";
          TARGET = "http://127.0.0.1:8095";
          METRICS_BIND = "127.0.0.1:8904";
          METRICS_BIND_NETWORK = "tcp";
          DIFFICULTY = 5;
          OG_PASSTHROUGH = true;
          COOKIE_DYNAMIC_DOMAIN = true;
          SERVE_ROBOTS_TXT = true;
        };
      };

      searxng = {
        enable = true;
        settings = {
          BIND = "127.0.0.1:8905";
          BIND_NETWORK = "tcp";
          TARGET = "http://127.0.0.1:8888";
          METRICS_BIND = "127.0.0.1:8906";
          METRICS_BIND_NETWORK = "tcp";
          DIFFICULTY = 5;
          OG_PASSTHROUGH = true;
          COOKIE_DYNAMIC_DOMAIN = true;
          SERVE_ROBOTS_TXT = true;
        };
      };
    };
  };
}
