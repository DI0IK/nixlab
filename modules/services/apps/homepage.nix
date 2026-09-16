{ config, ... }:

{
  services.homepage-dashboard = {
    enable = true;
    listenPort = 8082;
    allowedHosts = "home.${config.networking.domain},home.${config.networking.domain}:443,localhost:8082,127.0.0.1:8082";
    environmentFiles = [ "/var/lib/private/homepage-dashboard/homepage.env" ];

    settings = {
      title = "Homelab Dashboard";
      theme = "dark";
      color = "slate";
      headerStyle = "clean";
      statusStyle = "dot";
      cardBlur = "md";
      useEqualHeights = true;
      target = "_blank";
      disableIndexing = true;
      background = {
        image = "https://images.unsplash.com/photo-1506703719100-a0f3a48c0f86?auto=format&fit=crop&w=2560&q=80";
        blur = "sm";
        saturate = 90;
        brightness = 50;
        opacity = 70;
      };
      layout = [
        {
          "Media & Streaming" = {
            icon = "mdi-play-network";
          };
        }
        {
          "Apps & Services" = {
            icon = "mdi-grid-large";
          };
        }
        {
          "Management & Monitoring" = {
            icon = "mdi-server-network";
          };
        }
        {
          "Downloaders & Arr Stack" = {
            icon = "mdi-download-network";
            style = "row";
            columns = 4;
          };
        }
      ];
      quicklaunch = {
        searchDescriptions = true;
        provider = "custom";
        url = "https://search.dominikstahl.dev/search?q=";
        target = "_blank";
      };
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
          label = "Media Storage";
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
            "Calendar" = {
              widget = {
                type = "calendar";
                firstDayInWeek = "monday";
                view = "monthly";
                maxEvents = 10;
                showTime = true;
                integrations = [
                  {
                    type = "sonarr";
                    service_group = "Downloaders & Arr Stack";
                    service_name = "Sonarr";
                    color = "teal";
                  }
                  {
                    type = "radarr";
                    service_group = "Downloaders & Arr Stack";
                    service_name = "Radarr";
                    color = "red";
                  }
                  {
                    type = "lidarr";
                    service_group = "Downloaders & Arr Stack";
                    service_name = "Lidarr";
                    color = "amber";
                  }
                ];
              };
            };
          }
          {
            "Jellyfin" = {
              icon = "jellyfin.svg";
              href = "https://jellyfin.dominikstahl.dev";
              description = "Media Server";
              siteMonitor = "http://127.0.0.1:8096/health";
              widget = {
                type = "jellyfin";
                url = "http://127.0.0.1:8096";
                key = "{{HOMEPAGE_VAR_JELLYFIN_KEY}}";
                version = 2;
                fields = [
                  "movies"
                  "series"
                  "episodes"
                ];
                enableBlocks = true;
              };
            };
          }
          {
            "Jellyseerr" = {
              icon = "jellyseerr.svg";
              href = "https://requests.dominikstahl.dev";
              description = "Media Requests";
              siteMonitor = "http://127.0.0.1:5055/api/v1/status";
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
              siteMonitor = "http://127.0.0.1:4533/ping";
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
              siteMonitor = "http://127.0.0.1:3000";
            };
          }
          {
            "Immich" = {
              icon = "immich.svg";
              href = "https://photos.dominikstahl.dev";
              description = "Photo & Video Library";
              siteMonitor = "http://127.0.0.1:2283/api/server/ping";
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
              siteMonitor = "http://127.0.0.1:8888";
            };
          }
          {
            "ArchiveBox" = {
              icon = "archivebox.svg";
              href = "https://archive.dominikstahl.dev";
              description = "Web Archiver";
              siteMonitor = "http://127.0.0.1:8000";
            };
          }
          {
            "The Lounge" = {
              icon = "thelounge.svg";
              href = "https://irc.dominikstahl.dev";
              description = "IRC Client";
              siteMonitor = "http://127.0.0.1:9001";
            };
          }
          {
            "Redlib" = {
              icon = "redlib.svg";
              href = "https://redlib.dominikstahl.dev";
              description = "Reddit Frontend";
              siteMonitor = "http://127.0.0.1:8088";
            };
          }
          {
            "Koito" = {
              icon = "koito.svg";
              href = "https://koito.dominikstahl.dev";
              description = "ListenBrainz-compatible Scrobbler";
              siteMonitor = "http://127.0.0.1:4110";
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
              siteMonitor = "http://127.0.0.1:8123";
            };
          }
          {
            "Authentik" = {
              icon = "authentik.svg";
              href = "https://sso.dominikstahl.dev";
              description = "Identity & SSO";
              siteMonitor = "http://127.0.0.1:9000/-/health/live/";
            };
          }
          {
            "AdGuard Home" = {
              icon = "adguard-home.svg";
              href = "https://dns.dominikstahl.dev";
              description = "DNS & Ad Blocking";
              siteMonitor = "http://127.0.0.1:3001";
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
              siteMonitor = "http://127.0.0.1:3005/api/health";
            };
          }
          {
            "Guacamole" = {
              icon = "guacamole.svg";
              href = "https://guacamole.dominikstahl.dev/guacamole/";
              description = "Remote Desktop Gateway";
              siteMonitor = "http://127.0.0.1:8084/guacamole/";
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
              siteMonitor = "http://127.0.0.1:7878/ping";
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
              siteMonitor = "http://127.0.0.1:8989/ping";
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
              siteMonitor = "http://127.0.0.1:9696/ping";
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
              siteMonitor = "http://127.0.0.1:6767/ping";
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
              siteMonitor = "http://127.0.0.1:8686/ping";
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
              siteMonitor = "http://127.0.0.1:8080";
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
              siteMonitor = "http://127.0.0.1:7476";
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
    ];
  };

  # Impermanence persistence for Homepage data
  environment.persistence."/persist" = {
    directories = [
      "/var/lib/private/homepage-dashboard"
    ];
  };
}
