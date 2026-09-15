{ config, ... }:

{
  services.homepage-dashboard = {
    enable = true;
    listenPort = 8082;
    allowedHosts = "home.${config.networking.domain},home.${config.networking.domain}:443,localhost:8082,127.0.0.1:8082";
    environmentFiles = ["/var/lib/private/homepage-dashboard/homepage.env"];

    settings = {
      title = "Homelab Dashboard";
      headerStyle = "clean";
    };

    widgets = [
      {
        resources = {
          cpu = true;
          memory = true;
          disk = "/persist";
          cputemp = true;
          uptime = true;
          label = "System";
        };
      }
      {
        resources = {
          disk = "/data/media";
          label = "Media";
        };
      }
      {
        search = {
          provider = "custom";
          url = "https://search.dominikstahl.dev/search?q=";
          target = "_blank";
        };
      }
    ];

    services = [
      {
        "Media & Streaming" = [
          {
            "Jellyfin" = {
              icon = "jellyfin.svg";
              href = "https://jellyfin.dominikstahl.dev";
              description = "Media Server";
              widget = {
                type = "jellyfin";
                url = "http://127.0.0.1:8096";
                key = "{{HOMEPAGE_VAR_JELLYFIN_KEY}}";
                version = 2;
                fields = ["movies" "series" "episodes"];
                enableBlocks = true;
              };
            };
          }
          {
            "Jellyseerr" = {
              icon = "jellyseerr.svg";
              href = "https://requests.dominikstahl.dev";
              description = "Media Requests";
              widget = {
                type = "seerr";
                url = "http://127.0.0.1:5055";
                key = "{{HOMEPAGE_VAR_JELLYSEERR_KEY}}";
              };
            };
          }
          {
            "Navidrome" = {
              icon = "navidrome.svg";
              href = "https://music.dominikstahl.dev";
              description = "Music Server";
            };
          }
        ];
      }
      {
        "Downloaders & Arr Stack" = [
          {
            "Radarr" = {
              icon = "radarr.svg";
              href = "https://radarr.dominikstahl.dev";
              description = "Movies Management";
              widget = {
                type = "radarr";
                url = "http://127.0.0.1:7878";
                key = "{{HOMEPAGE_VAR_RADARR_KEY}}";
              };
            };
          }
          {
            "Sonarr" = {
              icon = "sonarr.svg";
              href = "https://sonarr.dominikstahl.dev";
              description = "TV Shows Management";
              widget = {
                type = "sonarr";
                url = "http://127.0.0.1:8989";
                key = "{{HOMEPAGE_VAR_SONARR_KEY}}";
              };
            };
          }
          {
            "Prowlarr" = {
              icon = "prowlarr.svg";
              href = "https://prowlarr.dominikstahl.dev";
              description = "Indexer Manager";
              widget = {
                type = "prowlarr";
                url = "http://127.0.0.1:9696";
                key = "{{HOMEPAGE_VAR_PROWLARR_KEY}}";
              };
            };
          }
          {
            "Bazarr" = {
              icon = "bazarr.svg";
              href = "https://bazarr.dominikstahl.dev";
              description = "Subtitles Manager";
              widget = {
                type = "bazarr";
                url = "http://127.0.0.1:6767";
                key = "{{HOMEPAGE_VAR_BAZARR_KEY}}";
              };
            };
          }
          {
            "Lidarr" = {
              icon = "lidarr.svg";
              href = "https://lidarr.dominikstahl.dev";
              description = "Music Management";
              widget = {
                type = "lidarr";
                url = "http://127.0.0.1:8686";
                key = "{{HOMEPAGE_VAR_LIDARR_KEY}}";
              };
            };
          }
          {
            "SABnzbd" = {
              icon = "sabnzbd.svg";
              href = "https://sabnzbd.dominikstahl.dev";
              description = "Usenet Downloader";
              widget = {
                type = "sabnzbd";
                url = "http://127.0.0.1:8080";
                key = "{{HOMEPAGE_VAR_SABNZBD_KEY}}";
              };
            };
          }
          {
            "qBittorrent" = {
              icon = "qbittorrent.svg";
              href = "https://qui.dominikstahl.dev";
              description = "Torrent Client";
              widget = {
                type = "qbittorrent";
                url = "{{HOMEPAGE_VAR_QBIT_URL}}";
                username = "username";
                password = "password";
              };
            };
          }
        ];
      }
      {
        "Apps & Services" = [
          {
            "Forgejo" = {
              icon = "forgejo.svg";
              href = "https://git.dominikstahl.dev";
              description = "Git Workspace";
            };
          }
          {
            "Immich" = {
              icon = "immich.svg";
              href = "https://photos.dominikstahl.dev";
              description = "Photo & Video Library";
              widget = {
                type = "immich";
                url = "http://127.0.0.1:2283";
                key = "{{HOMEPAGE_VAR_IMMICH_API_KEY}}";
                version = 2;
              };
            };
          }
          {
            "SearXNG" = {
              icon = "searxng.svg";
              href = "https://search.dominikstahl.dev";
              description = "Meta Search Engine";
            };
          }
          {
            "ArchiveBox" = {
              icon = "archivebox.svg";
              href = "https://archive.dominikstahl.dev";
              description = "Web Archiver";
            };
          }
          {
            "The Lounge" = {
              icon = "thelounge.svg";
              href = "https://irc.dominikstahl.dev";
              description = "IRC Client";
            };
          }
          {
            "Redlib" = {
              icon = "redlib.svg";
              href = "https://redlib.dominikstahl.dev";
              description = "Reddit Frontend";
            };
          }
          {
            "Koito" = {
              icon = "koito.svg";
              href = "https://koito.dominikstahl.dev";
              description = "ListenBrainz-compatible Scrobbler";
            };
          }
        ];
      }
      {
        "Management & Monitoring" = [
          {
            "Home Assistant" = {
              icon = "home-assistant.svg";
              href = "https://ha.dominikstahl.dev";
              description = "Home Automation";
            };
          }
          {
            "Authentik" = {
              icon = "authentik.svg";
              href = "https://sso.dominikstahl.dev";
              description = "Identity & SSO";
            };
          }
          {
            "AdGuard Home" = {
              icon = "adguard-home.svg";
              href = "https://dns.dominikstahl.dev";
              description = "DNS & Ad Blocking";
              widget = {
                type = "adguard";
                url = "http://127.0.0.1:3001";
              };
            };
          }
          {
            "Grafana" = {
              icon = "grafana.svg";
              href = "https://grafana.dominikstahl.dev";
              description = "Metrics & Dashboards";
            };
          }
        ];
      }
    ];
  };

  # Impermanence persistence for Homepage data
  environment.persistence."/persist" = {
    directories = [
      "/var/lib/private/homepage-dashboard"
    ];
  };
}
