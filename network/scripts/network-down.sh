#!/bin/bash
# network/scripts/network-down.sh
# Comprehensive cleanup script to safely stop the network and wipe all data.

set -e

NETWORK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
COMPOSE_FILE="${NETWORK_DIR}/docker-compose.yaml"

echo "🛑 [STOP] Bringing down the Fabric network..."

# 1. STOP & REMOVE CONTAINERS
# --volumes: Removes all volumes defined in the yaml
# --remove-orphans: Removes containers for services not defined in the yaml (useful if yaml was edited)
if [ -f "$COMPOSE_FILE" ]; then
    echo "🐳 Stopping containers and removing volumes..."
    docker-compose -f "$COMPOSE_FILE" down --volumes --remove-orphans || true
else
    echo "⚠️ Warning: docker-compose.yaml not found at $COMPOSE_FILE"
fi

# 2. CLEANUP PHYSICAL ARTIFACTS
# We use a Docker helper to bypass permission issues with root-owned cert folders
echo "🧹 Cleaning up identity certs and channel artifacts..."
docker run --rm -v "${NETWORK_DIR}:/network" alpine sh -c "rm -rf /network/organizations/* /network/channel-artifacts/*"

# 3. CLEANUP OTHER METADATA
rm -f "${NETWORK_DIR}/packaging/package_id.txt"
rm -f "${NETWORK_DIR}/scripts/log.txt"

# 4. PRUNE MISC
# Ensure no orphaned volumes or networks remain
echo "🧹 Final pruning of unused resources..."
docker network prune -f
docker volume prune -f

echo "✅ SUCCESS: Network is down and storage is clean."
echo "Tip: To start over, run ./network/scripts/bootstrap-ca.sh"
