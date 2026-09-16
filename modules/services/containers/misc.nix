{ ... }:

{
  virtualisation.oci-containers.containers = {
    # Redlib (private alternative Reddit frontend)
    redlib = {
      image = "ghcr.io/cycneuramus/containers:redlib";
      autoStart = true;
      ports = [
        "127.0.0.1:8088:8080"
      ];
      environment = {
        REDLIB_SFW_ONLY = "off";
        REDLIB_BANNER = "";
        REDLIB_ROBOTS_DISABLE_INDEXING = "on";
        REDLIB_PUSHSHIFT_FRONTEND = "undelete.pullpush.io";
        REDLIB_DEFAULT_THEME = "dark";
        REDLIB_DEFAULT_FRONT_PAGE = "default";
        REDLIB_DEFAULT_LAYOUT = "card";
        REDLIB_DEFAULT_WIDE = "off";
        REDLIB_DEFAULT_POST_SORT = "hot";
        REDLIB_DEFAULT_COMMENT_SORT = "confidence";
        REDLIB_DEFAULT_BLUR_SPOILER = "on";
        REDLIB_DEFAULT_SHOW_NSFW = "off";
        REDLIB_DEFAULT_BLUR_NSFW = "on";
        REDLIB_DEFAULT_USE_HLS = "on";
        REDLIB_DEFAULT_HIDE_HLS_NOTIFICATION = "off";
        REDLIB_DEFAULT_AUTOPLAY_VIDEOS = "off";
        REDLIB_DEFAULT_SUBSCRIPTIONS = "";
        REDLIB_DEFAULT_FILTERS = "";
        REDLIB_DEFAULT_HIDE_AWARDS = "off";
        REDLIB_DEFAULT_HIDE_SIDEBAR_AND_SUMMARY = "off";
        REDLIB_DEFAULT_DISABLE_VISIT_REDDIT_CONFIRMATION = "off";
        REDLIB_DEFAULT_HIDE_SCORE = "off";
        REDLIB_DEFAULT_FIXED_NAVBAR = "on";
      };
    };

    # Sungrow TLS tunnel (connects securely to inverter at 192.168.178.74:502)
    sungrow-tls-tunnel = {
      image = "docker.io/dockurr/stunnel:latest";
      autoStart = true;
      extraOptions = [
        "--network=host"
      ];
      volumes = [
        "/etc/stunnel/sungrow.conf:/stunnel.conf:ro"
      ];
    };

    # Sungrow Modbus Proxy for inverter telemetry
    sungrow-modbus-proxy = {
      image = "docker.io/tiagocoutinho/modbus-proxy:latest";
      autoStart = true;
      user = "0";
      cmd = [
        "-c"
        "/etc/modbus-proxy/modbus-proxy.yaml"
      ];
      extraOptions = [
        "--network=host"
        "--cap-add=NET_BIND_SERVICE"
      ];
      volumes = [
        "/etc/modbus-proxy/modbus-proxy.yaml:/etc/modbus-proxy/modbus-proxy.yaml:ro"
      ];
    };

    # Unpackerr (automated archive extraction for media downloads)
    unpackerr = {
      image = "docker.io/golift/unpackerr:latest";
      autoStart = true;
      extraOptions = [
        "--network=host"
      ];
      environment = {
        TZ = "Europe/Vienna";
      };
      volumes = [
        "/data/media:/data/media"
        "/persist/var/lib/unpackerr:/config"
      ];
    };

    # Qui (web interface for torrents)
    qui = {
      image = "ghcr.io/hotio/qui:release-1.29.0";
      autoStart = true;
      ports = [
        "127.0.0.1:7476:7476"
      ];
      environment = {
        PUID = "1000";
        PGID = "1000";
        UMASK = "002";
        TZ = "Europe/Berlin";
        QUI__METRICS_ENABLED = "true";
        QUI__METRICS_HOST = "0.0.0.0";
        QUI__METRICS_PORT = "9100";
      };
      environmentFiles = [
        "/persist/var/lib/qui/qui.env"
      ];
      volumes = [
        "/persist/var/lib/qui:/config"
        "/data/media:/data"
      ];
    };

    # Multiscrobbler (scrobble music from Navidrome/Jellyfin/Spotify to Last.fm/ListenBrainz)
    multiscrobbler = {
      image = "docker.io/foxxmd/multi-scrobbler:0.18.0";
      autoStart = true;
      extraOptions = [
        "--network=host"
      ];
      ports = [
        "127.0.0.1:9078:9078"
      ];
      environment = {
        TZ = "Europe/Berlin";
        BASE_URL = "https://msc.dominikstahl.dev";
      };
      volumes = [
        "/persist/var/lib/multiscrobbler:/config"
      ];
    };

    # Koito (Scrobble / Maloja alternative server)
    koito = {
      image = "docker.io/gabehf/koito:v0.3.2";
      autoStart = true;
      extraOptions = [
        "--network=host"
      ];
      ports = [
        "127.0.0.1:4110:4110"
      ];
      environment = {
        TZ = "Europe/Berlin";
        KOITO_ALLOWED_HOSTS = "koito.dominikstahl.dev,localhost,127.0.0.1";
        KOITO_DEFAULT_USERNAME = "admin";
      };
      volumes = [
        "/persist/var/lib/koito:/etc/koito"
      ];
    };
  };

  # Configuration files for stunnel and modbus-proxy
  environment.etc = {
    "stunnel/sungrow.conf".text = ''
      foreground = yes
      output = /var/log/stunnel.log

      [sungrow-tls-client]
      client = yes
      accept = 127.0.0.1:5020
      connect = 192.168.178.74:502

      # Force verification off to ignore the inverter's self-signed cert
      verifyPeer = no
      verify = 0

      delay = no
      renegotiation = no
      sslVersionMin = TLSv1.2

      socket = l:TCP_NODELAY=1
      socket = r:TCP_NODELAY=1
    '';

    "modbus-proxy/modbus-proxy.yaml".text = ''
      devices:
        - modbus:
            url: 127.0.0.1:5020
          listen:
            bind: 0.0.0.0:503
    '';
  };

  # Impermanence persistence for container configurations
  environment.persistence."/persist" = {
    directories = [
      "/var/lib/unpackerr"
      "/var/lib/qui"
      "/var/lib/multiscrobbler"
      "/var/lib/koito"
    ];
  };
}
