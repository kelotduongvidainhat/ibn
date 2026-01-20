#!/bin/bash
# fresh-start.sh
# Complete automation to reset and build the a 3-organization network from scratch.

set -e

# Colors for UI
GREEN='\033[0;32m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="${PROJECT_ROOT}/network/scripts"
export COMPOSE_PROJECT_NAME=fabric
export COMPOSE_IGNORE_ORPHANS=True

# -1. Pre-flight Checks
check_prerequisites() {
    echo -e "${BOLD}Step -1: Checking Technical Prerequisites...${NC}"
    local missing=0
    local RED='\033[0;31m'
    local GREEN='\033[0;32m'

    # 1. Check Binary Tools
    declare -A tools=(
        ["docker"]="docker.io"
        ["jq"]="jq"
        ["bc"]="bc"
        ["python3"]="python3"
        ["curl"]="curl"
    )

    for tool in "${!tools[@]}"; do
        if ! command -v "$tool" &> /dev/null; then
            echo -e "${RED}❌ Missing: $tool${NC} (Try: sudo apt-get install ${tools[$tool]})"
            missing=1
        else
            echo -e "${GREEN}✔ $tool: Found${NC}"
        fi
    done

    # 2. Check Docker Daemon & Compose
    if ! docker info &> /dev/null; then
        echo -e "${RED}❌ Docker daemon is not running.${NC}"
        missing=1
    fi

    if docker compose version &> /dev/null; then
        echo -e "${GREEN}✔ docker compose: Found${NC}"
    elif command -v docker-compose &> /dev/null; then
        echo -e "${GREEN}✔ docker-compose: Found${NC}"
    else
        echo -e "${RED}❌ Missing: docker compose${NC} (Check: https://docs.docker.com/compose/install/)"
        missing=1
    fi

    # 3. Check Python Libraries
    if ! python3 -c "import yaml" &> /dev/null; then
        echo -e "${RED}❌ Missing: Python PyYAML${NC} (Try: pip3 install pyyaml)"
        missing=1
    else
        echo -e "${GREEN}✔ Python PyYAML: Found${NC}"
    fi

    # 4. Check Fabric Binaries
    local bin_dir="${PROJECT_ROOT}/bin"
    if [ ! -f "${bin_dir}/configtxgen" ]; then
        echo -e "${RED}❌ Missing: Fabric Binaries in $bin_dir${NC}"
        missing=1
    else
        echo -e "${GREEN}✔ Fabric Binaries: Found${NC}"
    fi

    if [ $missing -eq 1 ]; then
        echo -e "\n${RED}${BOLD}STOP: Missing required technologies. Please install them and try again.${NC}"
        exit 1
    fi
    echo -e "${GREEN}${BOLD}Prerequisites Check Passed!${NC}\n"
}

check_prerequisites

echo -e "${BOLD}${CYAN}💥 STARTING TOTAL NETWORK RESET (MODULAR GOVERNANCE)${NC}"
echo "--------------------------------------------------------------------------------"

# 0. Full Network Shutdown & Cleanup
echo -e "${BOLD}Step 0: Deep Cleaning Infrastructure${NC}"
"${SCRIPTS_DIR}/network-down.sh"

# 1. Governance & Config Reset
echo -e "\n${BOLD}Step 1: Resetting Governance & Configs${NC}"
# Clear all audit logs and history to restart Org counter
rm -rf "${PROJECT_ROOT}/docs/logs/"*
mkdir -p "${PROJECT_ROOT}/docs/logs"

# Reset Modular Organization Registry (Keep only Orderer and Org1)
echo "🧹 Wiping modular organization registry (Orgs 2+)..."
rm -f "${PROJECT_ROOT}/network/config/orgs"/Org[2-9]*.yaml

# Assemble the global configtx.yaml from base + Org0 + Org1
"${PROJECT_ROOT}/network/scripts/assemble-config.sh"

# Reset modular compose directory for organizations (Keep Org1)
echo "🗑️ Wiping modular organization configs (Orgs 2+)..."
rm -f "${PROJECT_ROOT}/network/compose"/docker-compose-org[2-9]*.yaml
rm -f "${PROJECT_ROOT}/network/compose"/docker-compose-orderers.yaml

echo "🧹 Sanitizing Org1 Compose File..."
python3 <<EOF
import yaml
import os

path = '${PROJECT_ROOT}/network/compose/docker-compose-org1.yaml'
if os.path.exists(path):
    with open(path, 'r') as f:
        data = yaml.safe_load(f)
    
    # Whitelist of base services for Org1
    keep = ['ca_org1', 'couchdb0', 'peer0.org1.example.com']
    
    if 'services' in data:
        data['services'] = {k: v for k, v in data['services'].items() if k in keep}
        
    if 'volumes' in data and data['volumes']:
        data['volumes'] = {k: v for k, v in data['volumes'].items() if k in keep}

    with open(path, 'w') as f:
        yaml.dump(data, f, default_flow_style=False, sort_keys=False)
EOF

# 2. Primary Bootstrap (Org1 + Orderer)
echo -e "\n${BOLD}Step 2: Initial Bootstrap (Org1 + Orderer)${NC}"
./network/scripts/bootstrap-ca.sh

# Give the Orderer extra time to settle Raft leadership
echo "⏳ Waiting for Orderer Raft leadership (5s)..."
sleep 5

# 3. Sequential Scaling (Orgs 2 through 3)
echo -e "\n${BOLD}Step 3: Sequential Scaling (Orgs 2 through 3)${NC}"
for i in {2..3}; do
    echo -e "\n${BOLD}${CYAN}Step 3.$((i-1)): Provisioning next Organization...${NC}"
    "${SCRIPTS_DIR}/add-org.sh"
done

# 4. Global Chaincode Deployment (Required to generate package_id.txt)
echo -e "\n${BOLD}Step 4: Global Chaincode Deployment${NC}"
./network/scripts/deploy-caas.sh

# 5. Starting Application Services
echo -e "\n${BOLD}Step 5: Launching CaaS and Backend API${NC}"
export CHAINCODE_ID=$(cat "${PROJECT_ROOT}/network/packaging/package_id.txt")
docker compose -f network/compose/docker-compose-base.yaml -f network/compose/docker-compose-org1.yaml up -d --build chaincode-basic backend

# 6. Final Synchronization Check
echo -e "\n${BOLD}Step 6: Verifying Network Health${NC}"
sleep 10
"${SCRIPTS_DIR}/network-health.sh"

echo "--------------------------------------------------------------------------------"
echo -e "${GREEN}${BOLD}✅ FRESH START COMPLETE!${NC}"
echo -e "Backend API: ${BOLD}http://localhost:8080${NC}"
echo -e "Master CLI:  ${BOLD}./ibn-ctl${NC}"
