#!/usr/bin/env bash
# ==============================================================================
# scripts/evacuate-k8s.sh
# Run this from your fw13 laptop where kubectl is authenticated
# ==============================================================================
set -euo pipefail

DEST_DIR="/persist/home/dominik/homelab-evacuation"
DUMP_DIR="${DEST_DIR}/dumps"
PVC_DIR="${DEST_DIR}/pvcs"

mkdir -p "${DUMP_DIR}" "${PVC_DIR}"

echo "==> Step 1: Scaling down Kubernetes workloads to freeze dirty writes..."
kubectl scale deployment --all --replicas=0 -n arr 2>/dev/null || true
kubectl scale deployment --all --replicas=0 -n git 2>/dev/null || true
kubectl scale deployment --all --replicas=0 -n immich 2>/dev/null || true
kubectl scale deployment --all --replicas=0 -n authentik 2>/dev/null || true
kubectl scale deployment --all --replicas=0 -n home-assistant 2>/dev/null || true
kubectl scale statefulset --all --replicas=0 -n home-assistant 2>/dev/null || true

echo "==> Waiting 10 seconds for application pods to terminate..."
sleep 10

echo "==> Step 2: Extracting logical database dumps from CNPG clusters..."

# Helper to find primary pod in a namespace
find_primary_pod() {
  local ns="$1"
  local cluster="$2"
  local pod
  pod=$(kubectl get pods -n "${ns}" -l "cnpg.io/cluster=${cluster},role=primary" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)
  if [ -z "${pod}" ]; then
    pod=$(kubectl get pods -n "${ns}" -l "cnpg.io/cluster=${cluster}" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)
  fi
  if [ -z "${pod}" ]; then
    pod=$(kubectl get pods -n "${ns}" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)
  fi
  echo "${pod}"
}

# Helper to detect application database name by finding which DB actually has tables
dump_cnpg_db() {
  local ns="$1"
  local pod="$2"
  local preferred_db="$3"
  local out_file="$4"
  local extra_flags="$5"

  local target_db=""
  for db in $(kubectl exec -n "${ns}" -i "${pod}" -c postgres -- psql -U postgres -t -A -c "SELECT datname FROM pg_database WHERE NOT datistemplate;" 2>/dev/null); do
    local count
    count=$(kubectl exec -n "${ns}" -i "${pod}" -c postgres -- psql -U postgres -d "${db}" -t -A -c "SELECT count(*) FROM pg_tables WHERE schemaname = 'public';" 2>/dev/null || echo 0)
    if [ "${count}" -gt 0 ]; then
      echo "Found ${count} tables in database '${db}'."
      target_db="${db}"
      break
    fi
  done

  if [ -z "${target_db}" ]; then
    target_db="${preferred_db}"
  fi

  echo "Dumping database '${target_db}' from pod ${pod} (namespace: ${ns})..."
  # shellcheck disable=SC2086
  kubectl exec -n "${ns}" -i "${pod}" -c postgres -- \
    pg_dump -U postgres ${extra_flags} "${target_db}" > "${out_file}"
}

# 1. Forgejo Dump
FORGEJO_POD=$(find_primary_pod "git" "forgejo-db")
if [ -n "${FORGEJO_POD}" ]; then
  dump_cnpg_db "git" "${FORGEJO_POD}" "forgejo" "${DUMP_DIR}/forgejo.dump" "--format=custom --blobs"
else
  echo "Warning: Could not locate Forgejo database pod in namespace git!"
fi

# 2. Authentik Dump
AUTHENTIK_POD=$(find_primary_pod "authentik" "authentik-db")
if [ -n "${AUTHENTIK_POD}" ]; then
  dump_cnpg_db "authentik" "${AUTHENTIK_POD}" "authentik" "${DUMP_DIR}/authentik.dump" "--format=custom --blobs"
else
  echo "Warning: Could not locate Authentik database pod in namespace authentik!"
fi

# 3. Immich Dump
IMMICH_POD=$(find_primary_pod "immich" "immich")
if [ -n "${IMMICH_POD}" ]; then
  dump_cnpg_db "immich" "${IMMICH_POD}" "immich" "${DUMP_DIR}/immich.dump" "--format=custom --clean --if-exists"
else
  echo "Warning: Could not locate Immich database pod in namespace immich!"
fi

echo "==> Step 3: Verifying exported dumps..."
ls -lh "${DUMP_DIR}"

echo "==> Step 4: Evacuating PVC directories from NFS storage..."
DEFAULT_NFS_HOST="192.168.179.172"
DEFAULT_NFS_PATH="/mnt/nvme/homelab"

read -rp "Enter NFS server IP [${DEFAULT_NFS_HOST}]: " NFS_HOST
NFS_HOST="${NFS_HOST:-$DEFAULT_NFS_HOST}"

read -rp "Enter NFS export path containing PVC folders [${DEFAULT_NFS_PATH}]: " NFS_PATH
NFS_PATH="${NFS_PATH:-$DEFAULT_NFS_PATH}"

echo "Syncing ${NFS_HOST}:${NFS_PATH}/ -> ${PVC_DIR}/..."
# Use sudo on remote host to read 0600/0700 container files (e.g. databases, SSH keys, auth tokens)
# Exclude raw cnpg pgdata clusters (we already have clean logical pg_dumps in dumps/)
rsync -avP --sparse \
  --rsync-path="sudo rsync" \
  --exclude="cnpg/" \
  "truenas_admin@${NFS_HOST}:${NFS_PATH}/" "${PVC_DIR}/"

echo "==> Verification: Evacuation completed!"
du -sh "${PVC_DIR}"
echo "Total evacuated application state is safe at: ${DEST_DIR}"
