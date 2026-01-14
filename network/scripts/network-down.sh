#!/bin/bash
# network/scripts/network-down.sh
# Comprehensive cleanup script to safely stop the network and wipe all data.
# Refactored for Modular Infrastructure.

set -e

NETWORK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
COMPOSE_DIR="${NETWORK_DIR}/compose"

# --- CONFIGURATION ---
export COMPOSE_PROJECT_NAME=fabric
export COMPOSE_IGNORE_ORPHANS=True

echo "🛑 [STOP] Bringing down the Fabric network..."

# 1. DISCOVERY & STOP
# Find all modular compose files to ensure thorough cleanup
COMPOSE_FILES="-f ${COMPOSE_DIR}/docker-compose-base.yaml"
if [ -d "${COMPOSE_DIR}" ]; then
    for f in "${COMPOSE_DIR}"/docker-compose-org*.yaml; do
        if [ -f "$f" ]; then
            COMPOSE_FILES="${COMPOSE_FILES} -f $f"
        fi
    done
fi

# Fallback for legacy monolithic file if it exists
if [ -f "${NETWORK_DIR}/docker-compose.yaml" ]; then
    COMPOSE_FILES="${COMPOSE_FILES} -f ${NETWORK_DIR}/docker-compose.yaml"
fi

echo "🐳 Stopping containers and removing volumes..."
docker compose ${COMPOSE_FILES} down --volumes --remove-orphans || true

# 2. CLEANUP PHYSICAL ARTIFACTS
# We use a Docker helper to bypass permission issues with root-owned cert folders
echo "🧹 Cleaning up identity certs and channel artifacts..."
docker run --rm -v "${NETWORK_DIR}:/network" alpine sh -c "rm -rf /network/organizations/* /network/channel-artifacts/*"

# 3. CLEANUP OTHER METADATA
rm -f "${NETWORK_DIR}/packaging/package_id.txt"
rm -f "${NETWORK_DIR}/scripts/log.txt"

# 4. DEEP PRUNE
# This is the "Magic Bullet" that removes ghost volumes from previous sessions
echo "🧹 Final pruning of unused resources..."
docker network prune -f
docker volume prune -f
# Aggressive cleanup of project volumes
echo "🧹 Removing any remaining project volumes..."
docker volume ls -q | grep "^${COMPOSE_PROJECT_NAME}_" | xargs -r docker volume rm || true
docker volume ls -q | grep "^ibn_" | xargs -r docker volume rm || true

echo "✅ SUCCESS: Network is down and storage is clean."
