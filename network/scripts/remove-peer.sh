#!/bin/bash
# network/scripts/remove-peer.sh
# Safely removes a peer node from the infrastructure and configuration.

set -e

PEER_ID=$1    # e.g., peer3
ORG_NAME=$2   # e.g., org1

if [ -z "$PEER_ID" ] || [ -z "$ORG_NAME" ]; then
    echo "Usage: ./network/scripts/remove-peer.sh <peer_id> <org_name>"
    echo "Example: ./network/scripts/remove-peer.sh peer4 org1"
    exit 1
fi

NETWORK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Mapping
case "${ORG_NAME}" in
    "org1") DOMAIN="org1.example.com" ;;
    "org2") DOMAIN="org2.example.com" ;;
    *) echo "Error: Unknown organization ${ORG_NAME}"; exit 1 ;;
esac

PEER_NAME="${PEER_ID}.${DOMAIN}"

echo "🗑️ [START] Removing ${PEER_NAME}..."

# 1. STOP & REMOVE DOCKER CONTAINER
echo "🐳 Stopping and removing container..."
docker-compose -f "${NETWORK_DIR}/docker-compose.yaml" stop "${PEER_NAME}" || true
docker-compose -f "${NETWORK_DIR}/docker-compose.yaml" rm -f "${PEER_NAME}" || true

# 2. REMOVE DOCKER VOLUME
VOLUME_NAME="network_${PEER_NAME}"
echo "💾 Removing volume ${VOLUME_NAME}..."
docker volume rm "${VOLUME_NAME}" || echo "Warning: Volume ${VOLUME_NAME} not found or already removed."

# 3. UPDATE DOCKER COMPOSE (Python script for safe removal)
echo "📝 Updating docker-compose.yaml..."
python3 <<EOF
import yaml
import os

composed_path = '${NETWORK_DIR}/docker-compose.yaml'
if os.path.exists(composed_path):
    with open(composed_path, 'r') as f:
        data = yaml.safe_load(f)

    peer_name = '${PEER_NAME}'
    
    # Remove from services
    if 'services' in data and peer_name in data['services']:
        del data['services'][peer_name]
        print(f"Removed service {peer_name}")
    
    # Remove from volumes
    if 'volumes' in data and peer_name in data['volumes']:
        del data['volumes'][peer_name]
        print(f"Removed volume definition {peer_name}")

    with open(composed_path, 'w') as f:
        yaml.dump(data, f, default_flow_style=False, sort_keys=False)
EOF

# 4. CLEANUP PHYSICAL FOLDERS
PEER_BASE_DIR="${NETWORK_DIR}/organizations/peerOrganizations/${DOMAIN}/peers/${PEER_NAME}"
if [ -d "${PEER_BASE_DIR}" ]; then
    echo "📂 Cleaning up identity folders..."
    sudo rm -rf "${PEER_BASE_DIR}"
fi

echo "✅ SUCCESS: ${PEER_NAME} has been completely removed from infrastructure."
