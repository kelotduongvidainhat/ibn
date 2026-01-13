#!/bin/bash
# network/scripts/profile-gen.sh
# Generates portable Connection Profiles (JSON) for all organizations.

NETWORK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUTPUT_DIR="${NETWORK_DIR}/connection-profiles"
mkdir -p "${OUTPUT_DIR}"

# Define Colors
GREEN='\033[0;32m'
NC='\033[0m'
BOLD='\033[1m'

echo -e "${BOLD}📇 Generating Connection Profiles for all Organizations...${NC}"
echo "--------------------------------------------------------------------------------"

# Helper to read and escape PEM for JSON
function encode_pem() {
    python3 -c "import json, sys; print(json.dumps(sys.stdin.read()))" < "$1" | sed 's/^"//;s/"$//'
}

ORGS_DIRS=$(ls -d "${NETWORK_DIR}/organizations/peerOrganizations/"* 2>/dev/null)

for ORG_DIR in $ORGS_DIRS; do
    DOMAIN=$(basename "$ORG_DIR")
    ORG_NUM=$(echo $DOMAIN | grep -o '[0-9]\+' | head -n 1)
    if [ -z "$ORG_NUM" ]; then continue; fi
    MSP_ID="Org${ORG_NUM}MSP"
    
    echo -ne "📎 Processing ${BOLD}${MSP_ID}${NC}... "

    # 1. Gather CA Info
    CA_NAME="ca_${DOMAIN%%.*}"
    CA_URL_PORT=$(docker port "ca_org${ORG_NUM}" 7054 | cut -d: -f2)
    # Fallback to calculated port if docker port fails (container might be internal only)
    if [ -z "$CA_URL_PORT" ]; then
         CA_URL_PORT=$((7054 + (ORG_NUM-1)*1000))
         if [ $CA_URL_PORT -eq 9054 ]; then CA_URL_PORT=10054; elif [ $CA_URL_PORT -ge 10054 ]; then CA_URL_PORT=$((CA_URL_PORT+1000)); fi
    fi
    CA_PEM=$(encode_pem "${NETWORK_DIR}/organizations/fabric-ca/org${ORG_NUM}/ca-cert.pem")

    # 2. Gather Peer Info (Peer0)
    PEER_NAME="peer0.${DOMAIN}"
    PEER_PORT=$(docker port "${PEER_NAME}" 7051 | cut -d: -f2)
    PEER_PEM=$(encode_pem "${NETWORK_DIR}/organizations/peerOrganizations/${DOMAIN}/peers/${PEER_NAME}/tls/ca.crt")

    # 3. Generate JSON
    cat > "${OUTPUT_DIR}/${MSP_ID}_profile.json" <<EOF
{
    "name": "network-${DOMAIN}",
    "version": "1.0.0",
    "client": {
        "organization": "${MSP_ID}",
        "connection": {
            "timeout": {
                "peer": { "endorser": "300" },
                "orderer": "300"
            }
        }
    },
    "organizations": {
        "${MSP_ID}": {
            "mspid": "${MSP_ID}",
            "peers": [ "${PEER_NAME}" ],
            "certificateAuthorities": [ "ca-org${ORG_NUM}" ]
        }
    },
    "peers": {
        "${PEER_NAME}": {
            "url": "grpcs://localhost:${PEER_PORT}",
            "tlsCACerts": { "pem": "${PEER_PEM}" },
            "grpcOptions": {
                "ssl-target-name-override": "${PEER_NAME}",
                "hostnameOverride": "${PEER_NAME}"
            }
        }
    },
    "certificateAuthorities": {
        "ca-org${ORG_NUM}": {
            "url": "https://localhost:${CA_URL_PORT}",
            "caName": "ca-org${ORG_NUM}",
            "tlsCACerts": { "pem": "${CA_PEM}" },
            "httpOptions": { "verify": false }
        }
    }
}
EOF
    echo -e "${GREEN}DONE${NC} -> ${OUTPUT_DIR}/${MSP_ID}_profile.json"
done

echo "--------------------------------------------------------------------------------"
echo -e "${BOLD}✅ Cleanup: Profiles are ready in /network/connection-profiles/${NC}"
