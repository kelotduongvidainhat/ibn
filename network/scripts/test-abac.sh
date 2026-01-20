#!/bin/bash
# network/scripts/test-abac.sh
# Verifies Attribute-Based Access Control (ABAC) in the smart contract.

NC='\033[0m'
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
BOLD='\033[1m'

echo -e "${BLUE}${BOLD}=== ABAC Security Verification ===${NC}"

# Helper function to run a transaction as a specific user
run_as_user() {
    local USER_NAME=$1
    local MSP_ID=$2
    local FUNC=$3
    local ARGS=$4
    
    echo -e "\n👤 Testing as ${BOLD}${USER_NAME}${NC} (${MSP_ID})..."
    
    # Path inside the CLI container
    local USER_MSP="/opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/org1.example.com/users/${USER_NAME}@org1.example.com/msp"
    
    docker exec \
      -e CORE_PEER_MSPCONFIGPATH="${USER_MSP}" \
      -e CORE_PEER_LOCALMSPID="${MSP_ID}" \
      cli peer chaincode invoke \
        -o orderer.example.com:7050 \
        --tls \
        --cafile /opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/tls/ca.crt \
        -C mychannel \
        -n basic \
        -c "{\"Args\":[\"${FUNC}\", ${ARGS}]}" \
        --transient "{\"appraisedValue\":\"MTAwMA==\"}" \
        --peerAddresses peer0.org1.example.com:7051 \
        --tlsRootCertFiles /opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt \
        2>&1
}

# 1. Admin Test (Should Succeed)
RESULT=$(run_as_user "Admin" "Org1MSP" "CreateAsset" "\"abac-admin-01\", \"red\", \"10\", \"Admin\", \"\", \"\"")
if [[ $RESULT == *"Chaincode invoke successful"* ]]; then
    echo -e "${GREEN}✅ SUCCESS: Admin with 'admin' role was allowed to CreateAsset.${NC}"
else
    echo -e "${RED}❌ FAILURE: Admin was restricted unexpectedly.${NC}"
    echo "$RESULT"
fi

# 2. Manager Test (Should Succeed)
RESULT=$(run_as_user "Manager1" "Org1MSP" "CreateAsset" "\"abac-manager-01\", \"blue\", \"20\", \"Manager\", \"\", \"\"")
if [[ $RESULT == *"Chaincode invoke successful"* ]]; then
    echo -e "${GREEN}✅ SUCCESS: Manager1 with 'manager' role was allowed to CreateAsset.${NC}"
else
    echo -e "${RED}❌ FAILURE: Manager1 was restricted unexpectedly.${NC}"
    echo "$RESULT"
fi

# 3. Viewer Test (Should Fail)
RESULT=$(run_as_user "Viewer1" "Org1MSP" "CreateAsset" "\"abac-viewer-01\", \"green\", \"30\", \"Viewer\", \"\", \"\"")
if [[ $RESULT == *"access denied"* ]]; then
    echo -e "${GREEN}✅ SUCCESS: Viewer1 with 'viewer' role was correctly BLOCKED from CreateAsset.${NC}"
else
    echo -e "${RED}❌ FAILURE: Viewer1 was allowed to bypass security!${NC}"
    echo "$RESULT"
fi

echo -e "\n${BLUE}${BOLD}=== ABAC Verification Complete ===${NC}"
