{ config, ... }:

{
  services.homepage-dashboard = {
    enable = true;
    listenPort = 8082;
    allowedHosts = "home.${config.networking.domain},home.${config.networking.domain}:443,localhost:8082,127.0.0.1:8082";

    settings = {
      title = "Homelab Dashboard";
      headerStyle = "clean";
    };

    widgets = [
      {
        resources = {
          cpu = true;
          memory = true;
          disk = "/";
        };
      }
      {
        search = {
          provider = "searxng";
          url = "https://search.dominikstahl.dev";
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
            };
          }
          {
            "Jellyseerr" = {
              icon = "jellyseerr.svg";
              href = "https://requests.dominikstahl.dev";
              description = "Media Requests";
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
            };
          }
          {
            "Sonarr" = {
              icon = "sonarr.svg";
              href = "https://sonarr.dominikstahl.dev";
              description = "TV Shows Management";
            };
          }
          {
            "Prowlarr" = {
              icon = "prowlarr.svg";
              href = "https://prowlarr.dominikstahl.dev";
              description = "Indexer Manager";
            };
          }
          {
            "Bazarr" = {
              icon = "bazarr.svg";
              href = "https://bazarr.dominikstahl.dev";
              description = "Subtitles Manager";
            };
          }
          {
            "Lidarr" = {
              icon = "lidarr.svg";
              href = "https://lidarr.dominikstahl.dev";
              description = "Music Management";
            };
          }
          {
            "SABnzbd" = {
              icon = "sabnzbd.svg";
              href = "https://sabnzbd.dominikstahl.dev";
              description = "Usenet Downloader";
            };
          }
          {
            "qBittorrent" = {
              icon = "qbittorrent.svg";
              href = "https://qui.dominikstahl.dev";
              description = "Torrent Client";
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
