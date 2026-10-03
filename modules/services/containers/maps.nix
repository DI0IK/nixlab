{
  pkgs,
  ...
}:

let
  # Declarative GraphHopper configuration file (GraphHopper 10.x compatible)
  graphhopperConfig = pkgs.writeText "graphhopper-config.yml" ''
    graphhopper:
      datareader.file: /data/osm/germany-latest.osm.pbf
      graph.location: /data/graphhopper/cache

      # OSM Import settings: empty string imports all road and path types needed for multi-modal routing
      import.osm.ignored_highways: ""

      # Encoded values required by car.json, bike.json and foot.json
      graph.encoded_values: |
        car_access, car_average_speed, country, road_class, roundabout, max_speed, road_environment,
        foot_access, foot_average_speed, foot_priority, foot_road_access, hike_rating,
        bike_access, bike_average_speed, bike_priority, bike_road_access, bike_network, mtb_rating, ferry_speed

      # Memory access strategy: offload heavy edge/node index structures to NVMe memory-mapped files
      # to prevent Java OutOfMemoryError during large country imports while retaining fast routing
      graph.dataaccess.default_type: RAM
      graph.dataaccess.type.edges: FOREIGN_MMAP
      graph.dataaccess.type.nodes: FOREIGN_MMAP
      graph.dataaccess.type.nodes_ch.*: FOREIGN_MMAP
      graph.dataaccess.type.shortcuts_.*: FOREIGN_MMAP

      profiles:
        - name: car
          custom_model_files: [car.json]
        - name: bike
          custom_model_files: [bike.json]
        - name: foot
          custom_model_files: [foot.json]

      profiles_ch:
        - profile: car
        - profile: bike
        - profile: foot

      prepare.min_network_size: 200
      prepare.subnetworks.threads: 1
      prepare.ch.threads: 1

      routing.snap_preventions_default: tunnel, bridge, ferry
      routing.non_ch.max_waypoint_distance: 1000000

    server:
      application_connectors:
        - type: http
          port: 8989
          bind_host: 0.0.0.0
          max_request_header_size: 50k
      admin_connectors:
        - type: http
          port: 8990
          bind_host: 0.0.0.0
      request_log:
        appenders: []

    logging:
      appenders:
        - type: console
          time_zone: UTC
          log_format: "%d{yyyy-MM-dd HH:mm:ss.SSS} [%thread] %-5level %logger{36} - %msg%n"
  '';
in
{
  # Declarative directory creation for local SSD state directories
  systemd.tmpfiles.rules = [
    "d /persist/var/lib/maps 0755 root root -"
    "d /persist/var/lib/maps/web 0755 root root -"
    "d /persist/var/lib/maps/graphhopper 0755 root root -"
    "d /persist/var/lib/maps/photon 0755 root root -"
  ];

  # Impermanence persistence for high-IOPS search indices & routing graphs
  environment.persistence."/persist" = {
    directories = [
      "/var/lib/maps"
    ];
  };

  # CLI tools available in system environment
  environment.systemPackages = [
    pkgs.pmtiles
  ];

  # Podman OCI Container Microservices
  virtualisation.oci-containers.containers = {
    # 1. Maps Web Frontend (MapLibre responsive UI)
    maps-web = {
      image = "docker.io/library/nginx:alpine";
      autoStart = true;
      ports = [
        "127.0.0.1:8091:80"
      ];
      volumes = [
        "/persist/var/lib/maps/web:/usr/share/nginx/html:ro"
      ];
    };

    # 2. Vector Tile Server (TileServer-GL)
    maps-tiles = {
      image = "docker.io/maptiler/tileserver-gl:latest";
      autoStart = true;
      ports = [
        "127.0.0.1:8092:8080"
      ];
      volumes = [
        "/data/media/media/maps/tiles:/data"
      ];
      cmd = [
        "--file"
        "/data/germany.pmtiles"
        "--public_url"
        "https://maps.dominikstahl.dev/tiles"
      ];
    };

    # 3. Geocoding Engine (Photon / Lucene)
    maps-geocoding = {
      image = "docker.io/rtuszik/photon-docker:latest";
      autoStart = true;
      ports = [
        "127.0.0.1:2322:2322"
      ];
      environment = {
        REGION = "germany";
        LANGUAGES = "de,en";
      };
      volumes = [
        "/persist/var/lib/maps/photon:/photon/data"
      ];
    };

    # 4. Multi-modal Routing Engine (GraphHopper)
    maps-routing = {
      image = "docker.io/israelhikingmap/graphhopper:latest";
      autoStart = true;
      ports = [
        "127.0.0.1:8998:8989"
      ];
      environment = {
        JAVA_OPTS = "-Xmx4g -Xms2g";
      };
      volumes = [
        "/data/media/media/maps/osm:/data/osm:ro"
        "/persist/var/lib/maps/graphhopper:/data/graphhopper"
        "${graphhopperConfig}:/graphhopper/config.yml:ro"
      ];
      cmd = [
        "-i"
        "/data/osm/germany-latest.osm.pbf"
        "-o"
        "/data/graphhopper/cache"
        "-c"
        "/graphhopper/config.yml"
      ];
    };
  };

  # Automated initial dataset bootstrap service (OSM PBF & Vector PMTiles)
  systemd.services.maps-bootstrap = {
    description = "Bootstrap Map Datasets (OSM PBF & Vector Tiles)";
    after = [ "network-online.target" "data-media.mount" ];
    wants = [ "network-online.target" "data-media.mount" ];
    path = [ pkgs.curl pkgs.pmtiles pkgs.coreutils ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      TimeoutStartSec = "7200";
    };
    script = ''
      set -euo pipefail
      OSM_DIR="/data/media/media/maps/osm"
      TILES_DIR="/data/media/media/maps/tiles"
      PBF_FILE="$OSM_DIR/germany-latest.osm.pbf"
      TILES_FILE="$TILES_DIR/germany.pmtiles"

      mkdir -p "$OSM_DIR" "$TILES_DIR"

      # 1. Download Germany OSM PBF extract for GraphHopper routing if absent
      if [ ! -f "$PBF_FILE" ]; then
        echo "Downloading Germany OSM extract from Geofabrik (~4.2 GB)..."
        curl -fSL -o "$PBF_FILE.tmp" "https://download.geofabrik.de/europe/germany-latest.osm.pbf"
        mv "$PBF_FILE.tmp" "$PBF_FILE"
        echo "OSM PBF download completed: $PBF_FILE"
      else
        echo "OSM PBF already present: $PBF_FILE"
      fi

      # 2. Extract Germany vector tiles from Protomaps daily build if absent
      if [ ! -f "$TILES_FILE" ]; then
        echo "Discovering latest Protomaps build date..."
        BUILD_DATE=""
        for d in 0 1 2 3 4 5; do
          CHECK_DATE=$(date -d "$d days ago" +%Y%m%d)
          if curl -sfI "https://build.protomaps.com/$CHECK_DATE.pmtiles" > /dev/null; then
            BUILD_DATE="$CHECK_DATE"
            break
          fi
        done

        if [ -n "$BUILD_DATE" ]; then
          echo "Extracting Germany vector tiles from Protomaps build $BUILD_DATE (~5 GB)..."
          pmtiles extract "https://build.protomaps.com/$BUILD_DATE.pmtiles" "$TILES_FILE.tmp" \
            --bbox=5.86,47.27,15.04,55.05 \
            --maxzoom=14
          mv "$TILES_FILE.tmp" "$TILES_FILE"
          echo "Vector tiles extraction completed: $TILES_FILE"
        else
          echo "WARNING: Could not discover active Protomaps daily build URL."
        fi
      else
        echo "Vector tiles already present in $TILES_DIR"
      fi
    '';
  };

  # Automated monthly maps update service & timer
  systemd.services.maps-update = {
    description = "Monthly Maps Dataset Refresh";
    after = [ "network-online.target" "data-media.mount" ];
    wants = [ "network-online.target" "data-media.mount" ];
    path = [ pkgs.curl pkgs.pmtiles pkgs.coreutils pkgs.systemd ];
    serviceConfig = {
      Type = "oneshot";
      TimeoutStartSec = "7200";
    };
    script = ''
      set -euo pipefail
      OSM_DIR="/data/media/media/maps/osm"
      TILES_DIR="/data/media/media/maps/tiles"
      GRAPHHOPPER_CACHE="/persist/var/lib/maps/graphhopper/cache"
      PBF_FILE="$OSM_DIR/germany-latest.osm.pbf"
      TILES_FILE="$TILES_DIR/germany.pmtiles"

      mkdir -p "$OSM_DIR" "$TILES_DIR"

      echo "Updating Germany OSM extract from Geofabrik..."
      curl -fSL -o "$PBF_FILE.tmp" "https://download.geofabrik.de/europe/germany-latest.osm.pbf"
      mv "$PBF_FILE.tmp" "$PBF_FILE"

      echo "Discovering latest Protomaps build date..."
      BUILD_DATE=""
      for d in 0 1 2 3 4 5; do
        CHECK_DATE=$(date -d "$d days ago" +%Y%m%d)
        if curl -sfI "https://build.protomaps.com/$CHECK_DATE.pmtiles" > /dev/null; then
          BUILD_DATE="$CHECK_DATE"
          break
        fi
      done

      if [ -n "$BUILD_DATE" ]; then
        echo "Updating Germany vector tiles from Protomaps build $BUILD_DATE..."
        pmtiles extract "https://build.protomaps.com/$BUILD_DATE.pmtiles" "$TILES_FILE.tmp" \
          --bbox=5.86,47.27,15.04,55.05 \
          --maxzoom=14
        mv "$TILES_FILE.tmp" "$TILES_FILE"
      fi

      echo "Clearing GraphHopper cache to trigger index rebuild..."
      rm -rf "$GRAPHHOPPER_CACHE"

      echo "Restarting map services to load updated datasets..."
      systemctl restart podman-maps-tiles.service podman-maps-routing.service
      echo "Maps update completed successfully."
    '';
  };

  systemd.timers.maps-update = {
    description = "Monthly Maps Dataset Refresh Timer";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "*-*-01 03:00:00";
      Persistent = true;
      RandomizedDelaySec = "1800";
    };
  };

  # Service dependencies ensuring NFS mount and datasets are ready before starting containers
  systemd.services.podman-maps-tiles = {
    after = [ "data-media.mount" "maps-bootstrap.service" ];
    wants = [ "data-media.mount" "maps-bootstrap.service" ];
  };

  systemd.services.podman-maps-routing = {
    after = [ "data-media.mount" "maps-bootstrap.service" ];
    wants = [ "data-media.mount" "maps-bootstrap.service" ];
  };
}
