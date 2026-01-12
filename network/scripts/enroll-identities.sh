#!/bin/bash
# network/scripts/enroll-identities.sh
# Automates identity registration and enrollment using Fabric CA.

set -e

NETWORK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BIN_DIR="${NETWORK_DIR}/../bin"
export PATH="${BIN_DIR}:${PATH}"

echo "=== Fabric CA Enrollment Process ==="

# --- CONFIG.YAML GENERATOR ---
generate_config_yaml() {
    local target_dir=$1
    echo "NodeOUs:
  Enable: true
  ClientOUIdentifier:
    Certificate: cacerts/ca.crt
    OrganizationalUnitIdentifier: client
  PeerOUIdentifier:
    Certificate: cacerts/ca.crt
    OrganizationalUnitIdentifier: peer
  AdminOUIdentifier:
    Certificate: cacerts/ca.crt
    OrganizationalUnitIdentifier: admin
  OrdererOUIdentifier:
    Certificate: cacerts/ca.crt
    OrganizationalUnitIdentifier: orderer" > "${target_dir}/config.yaml"
}

# 1. Initialize Folders
mkdir -p "${NETWORK_DIR}/organizations/fabric-ca/org1"
mkdir -p "${NETWORK_DIR}/organizations/fabric-ca/orderer"

# --- ORG1 ENROLLMENT ---
echo "--- Enrolling & Registering Org1 ---"
ORG1_CA_HOME="${NETWORK_DIR}/organizations/fabric-ca/org1"
# We use ca-cert.pem because it has CA:TRUE
ORG1_ROOT_CERT="${ORG1_CA_HOME}/ca-cert.pem"

# Enroll CA Admin
FABRIC_CA_CLIENT_HOME="${ORG1_CA_HOME}" fabric-ca-client enroll -u https://admin:adminpw@localhost:7054 --caname ca-org1 --tls.certfiles "${ORG1_ROOT_CERT}"

# Register Identities
FABRIC_CA_CLIENT_HOME="${ORG1_CA_HOME}" fabric-ca-client register --caname ca-org1 --id.name peer0 --id.secret peer0pw --id.type peer --tls.certfiles "${ORG1_ROOT_CERT}"
FABRIC_CA_CLIENT_HOME="${ORG1_CA_HOME}" fabric-ca-client register --caname ca-org1 --id.name org1admin --id.secret org1adminpw --id.type admin --id.attrs 'role=admin:ecert' --tls.certfiles "${ORG1_ROOT_CERT}"
FABRIC_CA_CLIENT_HOME="${ORG1_CA_HOME}" fabric-ca-client register --caname ca-org1 --id.name user1 --id.secret user1pw --id.type client --id.attrs 'role=user:ecert' --tls.certfiles "${ORG1_ROOT_CERT}"

# Enroll Peer0 MSP
echo "--- Enrolling Peer0 MSP ---"
PEER_MSP_DIR="${NETWORK_DIR}/organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/msp"
mkdir -p "${PEER_MSP_DIR}"
FABRIC_CA_CLIENT_HOME="${ORG1_CA_HOME}" fabric-ca-client enroll -u https://peer0:peer0pw@localhost:7054 --caname ca-org1 -M "${PEER_MSP_DIR}" --tls.certfiles "${ORG1_ROOT_CERT}"
# Rename the downloaded root cert for predictability
cp "${PEER_MSP_DIR}/cacerts/"* "${PEER_MSP_DIR}/cacerts/ca.crt"
generate_config_yaml "${PEER_MSP_DIR}"

# Enroll Peer0 TLS
echo "--- Enrolling Peer0 TLS ---"
PEER_TLS_DIR="${NETWORK_DIR}/organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls"
mkdir -p "${PEER_TLS_DIR}"
FABRIC_CA_CLIENT_HOME="${ORG1_CA_HOME}" fabric-ca-client enroll -u https://peer0:peer0pw@localhost:7054 --caname ca-org1 --enrollment.profile tls --csr.hosts peer0.org1.example.com,localhost -M "${PEER_TLS_DIR}" --tls.certfiles "${ORG1_ROOT_CERT}"
cp "${PEER_TLS_DIR}/keystore/"* "${PEER_TLS_DIR}/server.key"
cp "${PEER_TLS_DIR}/signcerts/"* "${PEER_TLS_DIR}/server.crt"
# Use the Identity Root as TLS trust root since it's the same CA
cp "${ORG1_ROOT_CERT}" "${PEER_TLS_DIR}/ca.crt"

# Enroll Admin
echo "--- Enrolling Org1 Admin ---"
ADMIN_MSP_DIR="${NETWORK_DIR}/organizations/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp"
mkdir -p "${ADMIN_MSP_DIR}"
FABRIC_CA_CLIENT_HOME="${ORG1_CA_HOME}" fabric-ca-client enroll -u https://org1admin:org1adminpw@localhost:7054 --caname ca-org1 -M "${ADMIN_MSP_DIR}" --tls.certfiles "${ORG1_ROOT_CERT}"
cp "${ADMIN_MSP_DIR}/keystore/"* "${ADMIN_MSP_DIR}/keystore/priv_sk"
cp "${ADMIN_MSP_DIR}/signcerts/"* "${ADMIN_MSP_DIR}/signcerts/Admin@org1.example.com-cert.pem"
cp "${ADMIN_MSP_DIR}/cacerts/"* "${ADMIN_MSP_DIR}/cacerts/ca.crt"
generate_config_yaml "${ADMIN_MSP_DIR}"

# Build Org1 Root MSP
echo "--- Building Org1 Root MSP ---"
ORG_MSP_DIR="${NETWORK_DIR}/organizations/peerOrganizations/org1.example.com/msp"
mkdir -p "${ORG_MSP_DIR}/cacerts" "${ORG_MSP_DIR}/tlscacerts"
cp "${ORG1_ROOT_CERT}" "${ORG_MSP_DIR}/cacerts/ca.crt"
cp "${ORG1_ROOT_CERT}" "${ORG_MSP_DIR}/tlscacerts/ca.crt"
generate_config_yaml "${ORG_MSP_DIR}"

# --- ORDERER ENROLLMENT ---
echo "--- Enrolling & Registering Orderer ---"
ORD_CA_HOME="${NETWORK_DIR}/organizations/fabric-ca/orderer"
ORD_ROOT_CERT="${ORD_CA_HOME}/ca-cert.pem"

FABRIC_CA_CLIENT_HOME="${ORD_CA_HOME}" fabric-ca-client enroll -u https://admin:adminpw@localhost:9054 --caname ca-orderer --tls.certfiles "${ORD_ROOT_CERT}"
FABRIC_CA_CLIENT_HOME="${ORD_CA_HOME}" fabric-ca-client register --caname ca-orderer --id.name orderer --id.secret ordererpw --id.type orderer --tls.certfiles "${ORD_ROOT_CERT}"

# Enroll Orderer Identity (MSP)
ORD_MSP_DIR="${NETWORK_DIR}/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/msp"
mkdir -p "${ORD_MSP_DIR}"
FABRIC_CA_CLIENT_HOME="${ORD_CA_HOME}" fabric-ca-client enroll -u https://orderer:ordererpw@localhost:9054 --caname ca-orderer -M "${ORD_MSP_DIR}" --tls.certfiles "${ORD_ROOT_CERT}"
cp "${ORD_MSP_DIR}/cacerts/"* "${ORD_MSP_DIR}/cacerts/ca.crt"
generate_config_yaml "${ORD_MSP_DIR}"

# Enroll Orderer TLS
ORD_TLS_DIR="${NETWORK_DIR}/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/tls"
mkdir -p "${ORD_TLS_DIR}"
FABRIC_CA_CLIENT_HOME="${ORD_CA_HOME}" fabric-ca-client enroll -u https://orderer:ordererpw@localhost:9054 --caname ca-orderer --enrollment.profile tls --csr.hosts orderer.example.com,localhost -M "${ORD_TLS_DIR}" --tls.certfiles "${ORD_ROOT_CERT}"
cp "${ORD_TLS_DIR}/keystore/"* "${ORD_TLS_DIR}/server.key"
cp "${ORD_TLS_DIR}/signcerts/"* "${ORD_TLS_DIR}/server.crt"
cp "${ORD_ROOT_CERT}" "${ORD_TLS_DIR}/ca.crt"

# Orderer Root MSP
ORD_ROOT_MSP="${NETWORK_DIR}/organizations/ordererOrganizations/example.com/msp"
mkdir -p "${ORD_ROOT_MSP}/cacerts" "${ORD_ROOT_MSP}/tlscacerts"
cp "${ORD_ROOT_CERT}" "${ORD_ROOT_MSP}/cacerts/ca.crt"
cp "${ORD_ROOT_CERT}" "${ORD_ROOT_MSP}/tlscacerts/ca.crt"
generate_config_yaml "${ORD_ROOT_MSP}"

echo "Enrollment Complete."
