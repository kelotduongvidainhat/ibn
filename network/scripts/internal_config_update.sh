#!/bin/bash
# network/scripts/internal_config_update.sh
# Performs the Fetch -> Decode -> Modify -> Compute Delta -> Encode dance.

set -e

CHANNEL=$1
JSON_FILE=$2
MSP_ID=$3

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

echo "✍️ Adding $MSP_ID definition to $CONFIG_JSON..."
# Safely add or update the group
jq -s ".[0] * {\"channel_group\":{\"groups\":{\"Application\":{\"groups\": {\"$MSP_ID\": .[1]}}}}}" $CONFIG_JSON $JSON_FILE > $MODIFIED_JSON

echo "📦 Computing update delta..."
configtxlator proto_encode --input $CONFIG_JSON --type common.Config --output $ORIGINAL_PB
configtxlator proto_encode --input $MODIFIED_JSON --type common.Config --output $MODIFIED_PB
configtxlator compute_update --channel_id $CHANNEL --original $ORIGINAL_PB --updated $MODIFIED_PB --output $UPDATE_PB

echo "✉️ Wrapping update in envelope..."
configtxlator proto_decode --input $UPDATE_PB --type common.ConfigUpdate | jq '{"payload":{"header":{"channel_header":{"channel_id":"'$CHANNEL'", "type":2}},"data":{"config_update":.}}}' | configtxlator proto_encode --type common.Envelope --output $ENVELOPE_PB

echo "✅ Update envelope prepared: $ENVELOPE_PB"
