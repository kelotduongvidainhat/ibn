#!/bin/bash
# network/scripts/internal_config_remove.sh
# Performs the Fetch -> Decode -> Delete Org -> Compute Delta -> Encode dance.

set -e

CHANNEL=$1
MSP_ID=$2

# Paths within the CLI container
CONFIG_BLOCK="config_block.pb"
CONFIG_JSON="config.json"
MODIFIED_JSON="modified_config.json"
ORIGINAL_PB="original_config.pb"
MODIFIED_PB="modified_config.pb"
UPDATE_PB="update.pb"
UPDATE_JSON="update.json"
ENVELOPE_PB="update_in_envelope.pb"

echo "📥 Fetching latest config block for $CHANNEL..."
peer channel fetch config $CONFIG_BLOCK -c $CHANNEL -o orderer.example.com:7050 --tls --cafile /opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/tls/ca.crt

echo "🔓 Decoding config block..."
configtxlator proto_decode --input $CONFIG_BLOCK --type common.Block | jq .data.data[0].payload.data.config > $CONFIG_JSON

echo "🗑️ Removing $MSP_ID from Application group..."
# Delete the organization from the Application groups
jq "del(.channel_group.groups.Application.groups.\"$MSP_ID\")" $CONFIG_JSON > $MODIFIED_JSON

# Check if anything actually changed
if diff $CONFIG_JSON $MODIFIED_JSON > /dev/null; then
    echo "⚠️ $MSP_ID not found in channel configuration. Skipping update."
    exit 0
fi

echo "📦 Computing update delta..."
configtxlator proto_encode --input $CONFIG_JSON --type common.Config --output $ORIGINAL_PB
configtxlator proto_encode --input $MODIFIED_JSON --type common.Config --output $MODIFIED_PB
configtxlator compute_update --channel_id $CHANNEL --original $ORIGINAL_PB --updated $MODIFIED_PB --output $UPDATE_PB

echo "✉️ Wrapping update in envelope..."
configtxlator proto_decode --input $UPDATE_PB --type common.ConfigUpdate | jq '{"payload":{"header":{"channel_header":{"channel_id":"'$CHANNEL'", "type":2}},"data":{"config_update":.}}}' | configtxlator proto_encode --type common.Envelope --output $ENVELOPE_PB

echo "✅ Update envelope prepared: $ENVELOPE_PB"
