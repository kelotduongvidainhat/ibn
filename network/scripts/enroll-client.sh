#!/bin/bash
# network/scripts/enroll-client.sh
# Registers and enrolls a new client identity for a given organization.

set -e

CLIENT_ID=$1
ORG_NAME=$2

if [ -z "$CLIENT_ID" ] || [ -z "$ORG_NAME" ]; then
    echo "Usage: ./network/scripts/enroll-client.sh <client_id> <org_name>"
    echo "Example: ./network/scripts/enroll-client.sh user2 org1"
    exit 1
fi

NETWORK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BIN_DIR="${NETWORK_DIR}/../bin"
export PATH="${BIN_DIR}:${PATH}"

# --- DYNAMIC CONFIGURATION ---
ORG_NUM=$(echo $ORG_NAME | grep -o '[0-9]\+')
if [ -z "$ORG_NUM" ]; then
    echo "Error: Organization name must contain a number (e.g. org1)"
    exit 1
fi
DOMAIN="${ORG_NAME}.example.com"
MSP_ID="Org${ORG_NUM}MSP"

# CA Port logic (consistent with add-org.sh)
CA_PORT=$((7054 + (ORG_NUM-1)*1000))
if [ $CA_PORT -eq 9054 ]; then 
    CA_PORT=10054
elif [ $CA_PORT -ge 10054 ]; then 
    CA_PORT=$((CA_PORT+1000))
fi

CA_HOME="${NETWORK_DIR}/organizations/fabric-ca/${ORG_NAME}"
CA_CERT="${CA_HOME}/ca-cert.pem"
CLIENT_PW="${CLIENT_ID}pw"
CLIENT_DIR="${NETWORK_DIR}/organizations/peerOrganizations/${DOMAIN}/users/${CLIENT_ID}@${DOMAIN}"

echo "👤 [CLIENT] Onboarding ${CLIENT_ID} for ${ORG_NAME}..."

# 1. REGISTER
set +e
FABRIC_CA_CLIENT_HOME="${CA_HOME}" fabric-ca-client register --caname "ca-${ORG_NAME}" \
    --id.name "${CLIENT_ID}" --id.secret "${CLIENT_PW}" --id.type client \
    --tls.certfiles "${CA_CERT}" 2>/dev/null
set -e

# 2. ENROLL
mkdir -p "${CLIENT_DIR}/msp"
FABRIC_CA_CLIENT_HOME="${CA_HOME}" fabric-ca-client enroll -u "https://${CLIENT_ID}:${CLIENT_PW}@localhost:${CA_PORT}" \
    --caname "ca-${ORG_NAME}" -M "${CLIENT_DIR}/msp" --tls.certfiles "${CA_CERT}"

# Predictable naming for convenience
cp "${CLIENT_DIR}/msp/signcerts/"* "${CLIENT_DIR}/msp/signcerts/${CLIENT_ID}-cert.pem"
cp "${CLIENT_DIR}/msp/keystore/"* "${CLIENT_DIR}/msp/keystore/priv_sk"
cp "${CLIENT_DIR}/msp/cacerts/"* "${CLIENT_DIR}/msp/cacerts/ca.crt"

# 3. GENERATE CONNECTION PROFILE (REDUCED TEMPLATE)
CP_PATH="${CLIENT_DIR}/${CLIENT_ID}_connection.json"
echo "📝 Generating Connection Profile: ${CP_PATH}"

# Basic template - in a real production env, this would be highly detailed
cat > "${CP_PATH}" <<EOF
{
    "name": "ibn-network-${ORG_NAME}",
    "version": "1.0.0",
    "client": {
        "organization": "${MSP_ID}",
        "connection": {
            "timeout": {
                "peer": {
                    "endorser": "300"
                }
            }
        }
    },
    "organizations": {
        "${MSP_ID}": {
            "mspid": "${MSP_ID}",
            "peers": [
                "peer0.${DOMAIN}"
            ],
            "certificateAuthorities": [
                "ca-${ORG_NAME}"
            ]
        }
    },
    "peers": {
        "peer0.${DOMAIN}": {
            "url": "grpcs://localhost:$(docker port peer0.${DOMAIN} | grep '7051/tcp' | awk '{print $3}' | cut -d: -f2)",
            "tlsCACerts": {
                "path": "${NETWORK_DIR}/organizations/peerOrganizations/${DOMAIN}/peers/peer0.${DOMAIN}/tls/ca.crt"
            },
            "grpcOptions": {
                "ssl-target-name-override": "peer0.${DOMAIN}",
                "hostnameOverride": "peer0.${DOMAIN}"
            }
        }
    },
    "certificateAuthorities": {
        "ca-${ORG_NAME}": {
            "url": "https://localhost:${CA_PORT}",
            "caName": "ca-${ORG_NAME}",
            "tlsCACerts": {
                "path": "${CA_CERT}"
            },
            "httpOptions": {
                "verify": false
            }
        }
    }
}
EOF

echo "✅ [SUCCESS] Client ${CLIENT_ID} is ready. Connection Profile: ${CP_PATH}"
