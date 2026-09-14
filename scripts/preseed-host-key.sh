#!/usr/bin/env bash
# ==============================================================================
# scripts/preseed-host-key.sh
# Run this from fw13 after formatting the server with Disko
# ==============================================================================
set -euo pipefail

if [ -z "${1:-}" ]; then
  echo "Usage: $0 <SERVER_INSTALLER_IP>"
  echo "Extracts system-ssh-key from secrets.yaml and securely injects it into /mnt/persist/etc/ssh on the target server."
  exit 1
fi

SERVER_IP="$1"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SECRETS_FILE="${SCRIPT_DIR}/../secrets/secrets.yaml"

if [ ! -f "${SECRETS_FILE}" ]; then
  echo "Error: ${SECRETS_FILE} not found!"
  exit 1
fi

echo "==> Extracting system-ssh-key from ${SECRETS_FILE}..."
PRIVATE_KEY=$(sops -d --extract '["system-ssh-key"]' "${SECRETS_FILE}")

echo "==> Writing host key to root@${SERVER_IP}:/mnt/persist/etc/ssh..."
ssh -o StrictHostKeyChecking=accept-new "root@${SERVER_IP}" "mkdir -p -m 0755 /mnt/persist/etc/ssh"

ssh "root@${SERVER_IP}" bash -c "'
cat > /mnt/persist/etc/ssh/ssh_host_ed25519_key << \"EOF\"
${PRIVATE_KEY}
EOF
chmod 0600 /mnt/persist/etc/ssh/ssh_host_ed25519_key
ssh-keygen -y -f /mnt/persist/etc/ssh/ssh_host_ed25519_key > /mnt/persist/etc/ssh/ssh_host_ed25519_key.pub
chmod 0644 /mnt/persist/etc/ssh/ssh_host_ed25519_key.pub
'"

echo "==> Success! Host key pre-seeded on target server with strict permissions."
echo "You can now run: nixos-install --flake .#homelab --no-root-password --target-host root@${SERVER_IP}"
