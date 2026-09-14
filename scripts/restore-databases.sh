#!/usr/bin/env bash
# ==============================================================================
# scripts/restore-databases.sh
# Run this on the target NixOS host as root after PostgreSQL is running
# ==============================================================================
set -euo pipefail

DUMP_DIR="/persist/staging/dumps"

if [ ! -d "${DUMP_DIR}" ]; then
  echo "Error: Database dump directory ${DUMP_DIR} does not exist!"
  exit 1
fi

echo "==> Ensuring PostgreSQL is online..."
systemctl start postgresql
systemctl is-active --quiet postgresql || { echo "PostgreSQL service failed to start!"; exit 1; }

echo "==> 1. Restoring Forgejo database..."
if [ -f "${DUMP_DIR}/forgejo.dump" ]; then
  sudo -u postgres pg_restore -d forgejo --clean --if-exists --no-owner "${DUMP_DIR}/forgejo.dump" || true
  echo "Forgejo restored."
else
  echo "No forgejo.dump found in ${DUMP_DIR}"
fi

echo "==> 2. Restoring Authentik database..."
if [ -f "${DUMP_DIR}/authentik.dump" ]; then
  sudo -u postgres pg_restore -d authentik --clean --if-exists --no-owner "${DUMP_DIR}/authentik.dump" || true
  echo "Authentik restored."
else
  echo "No authentik.dump found in ${DUMP_DIR}"
fi

echo "==> 3. Initializing Immich database extensions and restoring schema..."
IMMICH_FILE=""
if [ -f "${DUMP_DIR}/immich.dump" ]; then
  IMMICH_FILE="${DUMP_DIR}/immich.dump"
elif [ -f "${DUMP_DIR}/immich.sql" ]; then
  IMMICH_FILE="${DUMP_DIR}/immich.sql"
fi

if [ -n "${IMMICH_FILE}" ]; then
  # Pre-create required extensions
  sudo -u postgres psql -d immich -c "CREATE EXTENSION IF NOT EXISTS vector;" || true
  sudo -u postgres psql -d immich -c "CREATE EXTENSION IF NOT EXISTS cube;" || true
  sudo -u postgres psql -d immich -c "CREATE EXTENSION IF NOT EXISTS earthdistance;" || true

  # Auto-detect binary custom format vs plain SQL
  if head -c 5 "${IMMICH_FILE}" | grep -q "PGDMP"; then
    echo "Detected custom binary dump format. Restoring with pg_restore..."
    sudo -u postgres pg_restore -d immich --clean --if-exists --no-owner "${IMMICH_FILE}" || true
  else
    echo "Restoring with pg_restore (or falling back to psql)..."
    sudo -u postgres pg_restore -d immich --clean --if-exists --no-owner "${IMMICH_FILE}" 2>/dev/null || \
      sudo -u postgres psql -d immich < "${IMMICH_FILE}" || true
  fi
  echo "Immich restored."
else
  echo "No immich dump found in ${DUMP_DIR}"
fi

echo "==> Database restorations completed successfully!"
read -rp "Clean up staging directory /persist/staging? (y/N): " CONFIRM
if [[ "${CONFIRM}" =~ ^[Yy]$ ]]; then
  rm -rf /persist/staging
  echo "Staging directory removed."
fi
