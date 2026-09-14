#!/usr/bin/env bash
# ==============================================================================
# scripts/migrate-permissions.sh
# Run this on the target bare-metal NixOS host as root
# ==============================================================================
set -euo pipefail

STAGING_DIR="/persist/staging"

if [ ! -d "${STAGING_DIR}" ]; then
  echo "Error: Staging directory ${STAGING_DIR} does not exist!"
  echo "Please rsync your evacuated data from fw13 into /persist/staging first."
  exit 1
fi

echo "==> Relocating application states to /persist/var/lib/..."

# If prowlarr-cross-seed was mistakenly placed into /persist/var/lib/prowlarr, fix it
if [ -d "/persist/staging/pvcs/arr/prowlarr" ] && [ -d "/persist/var/lib/prowlarr" ]; then
  echo "Fixing prowlarr directory from prior migration..."
  rm -rf /persist/var/lib/prowlarr
fi

migrate_pvc() {
  local pattern="$1"
  local target="$2"
  local src=""

  if [ -d "${STAGING_DIR}/pvcs/${pattern}" ]; then
    src="${STAGING_DIR}/pvcs/${pattern}"
  elif [ -d "${STAGING_DIR}/${pattern}" ]; then
    src="${STAGING_DIR}/${pattern}"
  else
    src=$(find "${STAGING_DIR}" -maxdepth 4 -type d -path "*/${pattern}" 2>/dev/null | head -n 1 || true)
  fi

  if [ -n "$src" ] && [ -d "$src" ]; then
    echo "Relocating: $src -> $target"
    mkdir -p "$(dirname "$target")"
    rm -rf "$target"
    mv "$src" "$target"
  else
    echo "Notice: No folder matching '${pattern}' found in staging (skipping)."
  fi
}

# Media Stack
migrate_pvc "arr/radarr"                    "/persist/var/lib/radarr"
migrate_pvc "arr/sonarr"                    "/persist/var/lib/sonarr"
migrate_pvc "arr/prowlarr"                  "/persist/var/lib/prowlarr"
migrate_pvc "arr/bazarr"                    "/persist/var/lib/bazarr"
migrate_pvc "arr/lidarr"                    "/persist/var/lib/lidarr"
migrate_pvc "arr/sabnzbd"                   "/persist/var/lib/sabnzbd"
migrate_pvc "arr/jellyfin"                  "/persist/var/lib/jellyfin"
migrate_pvc "arr/jellyseerr"                "/persist/var/lib/jellyseerr"
migrate_pvc "arr/navidrome"                 "/persist/var/lib/navidrome"
migrate_pvc "arr/qui"                       "/persist/var/lib/qui"
migrate_pvc "arr/unpackerr"                 "/persist/var/lib/unpackerr"

# Automation & Core Apps
migrate_pvc "home-assistant/data"           "/persist/var/lib/hass"
migrate_pvc "home-assistant/mosquitto-data" "/persist/var/lib/mosquitto"
migrate_pvc "lounge/data"                   "/persist/var/lib/thelounge"
migrate_pvc "adguard"                       "/persist/var/lib/AdGuardHome"
migrate_pvc "git/data"                      "/persist/var/lib/forgejo"
migrate_pvc "maloja/multi-scrobbler"        "/persist/var/lib/multiscrobbler"

# Ensure required mount directories exist for containers even if empty
mkdir -p /persist/var/lib/immich/upload /persist/var/lib/immich/model-cache
mkdir -p /persist/var/lib/authentik/media /persist/var/lib/authentik/custom-templates
mkdir -p /persist/var/lib/unpackerr /persist/var/lib/qui /persist/var/lib/multiscrobbler
mkdir -p /persist/var/lib/prowlarr /persist/var/lib/jellyseerr /persist/var/lib/AdGuardHome

echo "==> Aligning deterministic NixOS system user and group ownerships..."

chown_if_exists() {
  local user_group="$1"
  local target="$2"
  if [ -d "$target" ]; then
    echo "chown -R ${user_group} ${target}"
    chown -R "${user_group}" "${target}"
  fi
}

# Media Stack (static users)
chown_if_exists "radarr:media"           "/persist/var/lib/radarr"
chown_if_exists "sonarr:media"           "/persist/var/lib/sonarr"
chown_if_exists "bazarr:media"           "/persist/var/lib/bazarr"
chown_if_exists "lidarr:media"           "/persist/var/lib/lidarr"
chown_if_exists "sabnzbd:media"          "/persist/var/lib/sabnzbd"
chown_if_exists "jellyfin:media"         "/persist/var/lib/jellyfin"
chown_if_exists "navidrome:media"        "/persist/var/lib/navidrome"

# Automation & Core Services (static users)
chown_if_exists "hass:hass"              "/persist/var/lib/hass"
chown_if_exists "mosquitto:mosquitto"    "/persist/var/lib/mosquitto"
chown_if_exists "thelounge:thelounge"    "/persist/var/lib/thelounge"
chown_if_exists "forgejo:forgejo"        "/persist/var/lib/forgejo"

# DynamicUser services (systemd requires root ownership and 0700 mode)
chown -R root:root /persist/var/lib/prowlarr /persist/var/lib/jellyseerr /persist/var/lib/AdGuardHome
chmod 0700 /persist/var/lib/prowlarr /persist/var/lib/jellyseerr /persist/var/lib/AdGuardHome

# Containers (run as root or dedicated UID)
chown_if_exists "root:root"              "/persist/var/lib/immich"
chown_if_exists "1000:1000"              "/persist/var/lib/authentik"
chown_if_exists "1000:1000"              "/persist/var/lib/unpackerr"
chown_if_exists "root:root"              "/persist/var/lib/qui"
chown_if_exists "root:root"              "/persist/var/lib/multiscrobbler"

echo "==> Success! All application state directories are in place with correct permissions."
