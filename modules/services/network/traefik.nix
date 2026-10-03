{ config, ... }:

{
  services.traefik = {
    enable = true;

    staticConfigOptions = {
      api.dashboard = false;

      entryPoints = {
        metrics = {
          address = "127.0.0.1:9101";
        };

        web = {
          address = ":80";
        };

        websecure = {
          address = ":443";
          # Strict PROXY Protocol v2 parsing from VPS endpoints
          proxyProtocol = {
            insecure = false;
            trustedIPs = [
              "172.30.32.1/32"
              "fd86:ea04:1115::1/128"
            ];
          };
          forwardedHeaders = {
            insecure = false;
            trustedIPs = [
              "172.30.32.1/32"
              "fd86:ea04:1115::1/128"
            ];
          };
        };
      };

      metrics = {
        prometheus = {
          entryPoint = "metrics";
          addEntryPointsLabels = true;
          addRoutersLabels = true;
        };
      };
    };

    # Declarative routing and TLS definitions for local services
    dynamicConfigOptions = {
      tls = {
        certificates = [
          {
            certFile = "/var/lib/acme/dominikstahl.dev/fullchain.pem";
            keyFile = "/var/lib/acme/dominikstahl.dev/key.pem";
            stores = [ "default" ];
          }
        ];
        stores.default.defaultCertificate = {
          certFile = "/var/lib/acme/dominikstahl.dev/fullchain.pem";
          keyFile = "/var/lib/acme/dominikstahl.dev/key.pem";
        };
      };

      http = {
        middlewares = {
          authentik = {
            forwardAuth = {
              address = "http://127.0.0.1:9000/outpost.goauthentik.io/auth/traefik";
              trustForwardHeader = true;
              maxResponseBodySize = 4194304;
              authResponseHeaders = [
                "X-authentik-username"
                "X-authentik-groups"
                "X-authentik-entitlements"
                "X-authentik-email"
                "X-authentik-name"
                "X-authentik-uid"
                "X-authentik-jwt"
                "X-authentik-meta-jwks"
                "X-authentik-meta-outpost"
                "X-authentik-meta-provider"
                "X-authentik-meta-app"
                "X-authentik-meta-version"
              ];
            };
          };
          maps-strip-tiles = {
            stripPrefix = {
              prefixes = [ "/tiles" ];
            };
          };
          maps-cors = {
            headers = {
              accessControlAllowMethods = [
                "GET"
                "OPTIONS"
              ];
              accessControlAllowOriginList = [ "*" ];
              accessControlMaxAge = 86400;
            };
          };
        };

        routers = {
          authentik-outpost = {
            rule = "PathPrefix(`/outpost.goauthentik.io/`)";
            priority = 1000;
            service = "authentik";
            entryPoints = [ "websecure" ];
            tls = { };
          };
          jellyfin = {
            rule = "Host(`jellyfin.dominikstahl.dev`)";
            service = "jellyfin";
            entryPoints = [ "websecure" ];
            tls = { };
          };
          jellyseerr = {
            rule = "Host(`requests.dominikstahl.dev`)";
            service = "jellyseerr";
            entryPoints = [ "websecure" ];
            tls = { };
          };
          navidrome = {
            rule = "Host(`music.dominikstahl.dev`)";
            service = "navidrome";
            entryPoints = [ "websecure" ];
            tls = { };
          };
          homeassistant = {
            rule = "Host(`ha.dominikstahl.dev`)";
            service = "homeassistant";
            entryPoints = [ "websecure" ];
            tls = { };
          };
          forgejo = {
            rule = "Host(`git.dominikstahl.dev`)";
            service = "forgejo";
            entryPoints = [ "websecure" ];
            tls = { };
          };
          immich = {
            rule = "Host(`photos.dominikstahl.dev`)";
            service = "immich";
            entryPoints = [ "websecure" ];
            tls = { };
          };
          authentik = {
            rule = "Host(`sso.dominikstahl.dev`)";
            service = "authentik";
            entryPoints = [ "websecure" ];
            tls = { };
          };
          adguard = {
            rule = "Host(`dns.dominikstahl.dev`)";
            service = "adguard";
            middlewares = [ "authentik" ];
            entryPoints = [ "websecure" ];
            tls = { };
          };
          thelounge = {
            rule = "Host(`irc.dominikstahl.dev`)";
            service = "thelounge";
            entryPoints = [ "websecure" ];
            tls = { };
          };
          searxng = {
            rule = "Host(`search.dominikstahl.dev`)";
            service = "searxng";
            entryPoints = [ "websecure" ];
            tls = { };
          };
          radarr = {
            rule = "Host(`radarr.dominikstahl.dev`)";
            service = "radarr";
            middlewares = [ "authentik" ];
            entryPoints = [ "websecure" ];
            tls = { };
          };
          sonarr = {
            rule = "Host(`sonarr.dominikstahl.dev`)";
            service = "sonarr";
            middlewares = [ "authentik" ];
            entryPoints = [ "websecure" ];
            tls = { };
          };
          prowlarr = {
            rule = "Host(`prowlarr.dominikstahl.dev`)";
            service = "prowlarr";
            middlewares = [ "authentik" ];
            entryPoints = [ "websecure" ];
            tls = { };
          };
          bazarr = {
            rule = "Host(`bazarr.dominikstahl.dev`)";
            service = "bazarr";
            middlewares = [ "authentik" ];
            entryPoints = [ "websecure" ];
            tls = { };
          };
          lidarr = {
            rule = "Host(`lidarr.dominikstahl.dev`)";
            service = "lidarr";
            middlewares = [ "authentik" ];
            entryPoints = [ "websecure" ];
            tls = { };
          };
          sabnzbd = {
            rule = "Host(`sabnzbd.dominikstahl.dev`)";
            service = "sabnzbd";
            middlewares = [ "authentik" ];
            entryPoints = [ "websecure" ];
            tls = { };
          };
          qui = {
            rule = "Host(`qui.dominikstahl.dev`)";
            service = "qui";
            entryPoints = [ "websecure" ];
            tls = { };
          };
          multiscrobbler = {
            rule = "Host(`msc.dominikstahl.dev`)";
            service = "multiscrobbler";
            middlewares = [ "authentik" ];
            entryPoints = [ "websecure" ];
            tls = { };
          };
          koito = {
            rule = "Host(`koito.dominikstahl.dev`)";
            service = "koito";
            entryPoints = [ "websecure" ];
            tls = { };
          };
          redlib = {
            rule = "Host(`redlib.dominikstahl.dev`)";
            service = "redlib";
            entryPoints = [ "websecure" ];
            tls = { };
          };
          grafana = {
            rule = "Host(`grafana.dominikstahl.dev`)";
            service = "grafana";
            entryPoints = [ "websecure" ];
            tls = { };
          };
          homepage = {
            rule = "Host(`home.dominikstahl.dev`)";
            service = "homepage";
            entryPoints = [ "websecure" ];
            tls = { };
          };
          archivebox = {
            rule = "Host(`archive.dominikstahl.dev`)";
            service = "archivebox";
            entryPoints = [ "websecure" ];
            tls = { };
          };
          guacamole = {
            rule = "Host(`guacamole.dominikstahl.dev`)";
            service = "guacamole";
            entryPoints = [ "websecure" ];
            tls = { };
          };
          paperless = {
            rule = "Host(`paperless.dominikstahl.dev`)";
            service = "paperless";
            entryPoints = [ "websecure" ];
            tls = { };
          };
          panel = {
            rule = "Host(`panel.dominikstahl.dev`)";
            service = "panel";
            entryPoints = [ "websecure" ];
            tls = { };
          };
          wings = {
            rule = "Host(`wings.dominikstahl.dev`)";
            service = "wings";
            entryPoints = [ "websecure" ];
            tls = { };
          };
          spapi = {
            rule = "Host(`sp-api.dominikstahl.dev`)";
            service = "spapi";
            entryPoints = [ "websecure" ];
            tls = { };
          };
          ycast = {
            rule = "Host(`radiodenon.com`) || Host(`*.radiodenon.com`) || Host(`vtuner.com`) || Host(`*.vtuner.com`) || Host(`radiomarantz.com`) || Host(`*.radiomarantz.com`) || HostRegexp(`^.+\\.radiodenon\\.com$`) || HostRegexp(`^.+\\.vtuner\\.com$`)";
            service = "ycast";
            entryPoints = [ "web" ];
          };
          mealie = {
            rule = "Host(`mealie.dominikstahl.dev`)";
            service = "mealie";
            entryPoints = [ "websecure" ];
            tls = { };
          };
          matrix = {
            rule = "Host(`matrix.dominikstahl.dev`) || (Host(`dominikstahl.dev`) && PathPrefix(`/.well-known/matrix`))";
            service = "matrix";
            entryPoints = [ "websecure" ];
            tls = { };
          };
          lemmy-backend = {
            rule = "Host(`lemmy.dominikstahl.dev`) && (PathPrefix(`/api`) || PathPrefix(`/pictrs`) || PathPrefix(`/feeds`) || PathPrefix(`/nodeinfo`) || PathPrefix(`/.well-known`) || Method(`POST`) || HeaderRegexp(`Accept`, `application/(activity|ld)\\+json`))";
            service = "lemmy-backend";
            entryPoints = [ "websecure" ];
            priority = 100;
            tls = { };
          };
          lemmy-ui = {
            rule = "Host(`lemmy.dominikstahl.dev`)";
            service = "lemmy-ui";
            entryPoints = [ "websecure" ];
            priority = 50;
            tls = { };
          };
          tubearchivist = {
            rule = "Host(`tubearchivist.dominikstahl.dev`)";
            service = "tubearchivist";
            entryPoints = [ "websecure" ];
            tls = { };
          };
          kiwix = {
            rule = "Host(`kiwix.dominikstahl.dev`)";
            service = "kiwix";
            entryPoints = [ "websecure" ];
            tls = { };
          };
          gitlab-time-analysis = {
            rule = "Host(`se-timetracking.dominikstahl.dev`)";
            service = "gitlab-time-analysis";
            entryPoints = [ "websecure" ];
            tls = { };
          };
          maps-tiles = {
            rule = "Host(`maps.dominikstahl.dev`) && PathPrefix(`/tiles`)";
            service = "maps-tiles";
            middlewares = [
              "maps-strip-tiles"
              "maps-cors"
              "authentik"
            ];
            priority = 100;
            entryPoints = [ "websecure" ];
            tls = { };
          };
          maps-route = {
            rule = "Host(`maps.dominikstahl.dev`) && (PathPrefix(`/route`) || PathPrefix(`/gh`))";
            service = "maps-route";
            middlewares = [
              "maps-cors"
              "authentik"
            ];
            priority = 100;
            entryPoints = [ "websecure" ];
            tls = { };
          };
          maps-geocode = {
            rule = "Host(`maps.dominikstahl.dev`) && (PathPrefix(`/api`) || PathPrefix(`/reverse`))";
            service = "maps-geocode";
            middlewares = [
              "maps-cors"
              "authentik"
            ];
            priority = 100;
            entryPoints = [ "websecure" ];
            tls = { };
          };
          maps = {
            rule = "Host(`maps.dominikstahl.dev`)";
            service = "maps-web";
            middlewares = [
              "authentik"
            ];
            priority = 10;
            entryPoints = [ "websecure" ];
            tls = { };
          };
        };

        services = {
          homepage.loadBalancer.servers = [ { url = "http://127.0.0.1:8082"; } ];
          jellyfin.loadBalancer.servers = [ { url = "http://127.0.0.1:8096"; } ];
          jellyseerr.loadBalancer.servers = [ { url = "http://127.0.0.1:5055"; } ];
          navidrome.loadBalancer.servers = [ { url = "http://127.0.0.1:4533"; } ];
          homeassistant.loadBalancer.servers = [ { url = "http://127.0.0.1:8123"; } ];
          forgejo.loadBalancer.servers = [ { url = "http://127.0.0.1:3000"; } ];
          immich.loadBalancer.servers = [ { url = "http://127.0.0.1:2283"; } ];
          authentik.loadBalancer.servers = [ { url = "http://127.0.0.1:9000"; } ];
          adguard.loadBalancer.servers = [ { url = "http://127.0.0.1:3001"; } ];
          thelounge.loadBalancer.servers = [ { url = "http://127.0.0.1:9001"; } ];
          searxng.loadBalancer.servers = [ { url = "http://127.0.0.1:8888"; } ];
          radarr.loadBalancer.servers = [ { url = "http://127.0.0.1:7878"; } ];
          sonarr.loadBalancer.servers = [ { url = "http://127.0.0.1:8989"; } ];
          prowlarr.loadBalancer.servers = [ { url = "http://127.0.0.1:9696"; } ];
          bazarr.loadBalancer.servers = [ { url = "http://127.0.0.1:6767"; } ];
          lidarr.loadBalancer.servers = [ { url = "http://127.0.0.1:8686"; } ];
          sabnzbd.loadBalancer.servers = [ { url = "http://127.0.0.1:8080"; } ];
          qui.loadBalancer.servers = [ { url = "http://127.0.0.1:7476"; } ];
          multiscrobbler.loadBalancer.servers = [ { url = "http://127.0.0.1:9078"; } ];
          koito.loadBalancer.servers = [ { url = "http://127.0.0.1:4110"; } ];
          redlib.loadBalancer.servers = [ { url = "http://127.0.0.1:8088"; } ];
          grafana.loadBalancer.servers = [ { url = "http://127.0.0.1:3005"; } ];
          archivebox.loadBalancer.servers = [ { url = "http://127.0.0.1:8000"; } ];
          guacamole.loadBalancer.servers = [ { url = "http://127.0.0.1:8084"; } ];
          paperless.loadBalancer.servers = [ { url = "http://127.0.0.1:28010"; } ];
          panel.loadBalancer.servers = [ { url = "http://127.0.0.1:8008"; } ];
          wings.loadBalancer.servers = [ { url = "http://10.100.0.2:8080"; } ];
          spapi.loadBalancer.servers = [ { url = "http://192.168.179.10:2345"; } ];
          ycast.loadBalancer.servers = [ { url = "http://127.0.0.1:8010"; } ];
          mealie.loadBalancer.servers = [ { url = "http://127.0.0.1:9002"; } ];
          matrix.loadBalancer.servers = [ { url = "http://127.0.0.1:6167"; } ];
          lemmy-backend.loadBalancer.servers = [ { url = "http://127.0.0.1:8536"; } ];
          lemmy-ui.loadBalancer.servers = [ { url = "http://127.0.0.1:8537"; } ];
          tubearchivist.loadBalancer.servers = [ { url = "http://127.0.0.1:8005"; } ];
          kiwix.loadBalancer.servers = [ { url = "http://127.0.0.1:8095"; } ];
          gitlab-time-analysis.loadBalancer.servers = [ { url = "http://127.0.0.1:3020"; } ];
          maps-web.loadBalancer.servers = [ { url = "http://127.0.0.1:8091"; } ];
          maps-tiles.loadBalancer.servers = [ { url = "http://127.0.0.1:8092"; } ];
          maps-route.loadBalancer.servers = [ { url = "http://127.0.0.1:8998"; } ];
          maps-geocode.loadBalancer.servers = [ { url = "http://127.0.0.1:2322"; } ];
        };
      };
    };
  };

  # Wait for initial certificate generation before starting Traefik
  systemd.services.traefik = {
    wants = [ "acme-dominikstahl.dev.service" ];
    after = [ "acme-dominikstahl.dev.service" ];
  };
}
