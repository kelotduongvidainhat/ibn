#!/bin/bash
# network/scripts/assemble-config.sh
# Dynamically assembles configtx.yaml from modular components.

set -e

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CONFIG_DIR="${PROJECT_ROOT}/network/config"
ORGS_DIR="${CONFIG_DIR}/orgs"
TEMPLATE="${CONFIG_DIR}/templates/configtx-base.yaml"
OUTPUT="${PROJECT_ROOT}/network/configtx.yaml"

echo "🧩 [ASSEMBLER] Generating modular configtx.yaml..."

# 1. Start with Organizations header
echo "Organizations:" > "${OUTPUT}"

# 2. Append all Org modules (ensuring they start with - &id)
for f in $(ls "${ORGS_DIR}"/*.yaml | sort); do
    cat "$f" >> "${OUTPUT}"
done

# 3. Append base configuration (Capabilities, Defaults)
cat "${TEMPLATE}" >> "${OUTPUT}"

# 4. Generate Profiles section
cat >> "${OUTPUT}" <<EOF

Profiles:
  Org1Channel:
    Policies: *id001
    Capabilities: *id002
    Consortium: SampleConsortium
    Orderer:
      OrdererType: etcdraft
      EtcdRaft: *id003
      Addresses: *id004
      BatchTimeout: 2s
      BatchSize: *id005
      Organizations:
      - *id006
      Policies: *id007
      Capabilities:
        V2_0: true
    Application:
      Organizations:
      - *id008
      Policies: *id009
      Capabilities:
        V2_5: true
  DefaultChannel:
    Policies: *id001
    Capabilities: *id002
    Orderer:
      OrdererType: etcdraft
      EtcdRaft: *id003
      Addresses: *id004
      BatchTimeout: 2s
      BatchSize: *id005
      Organizations:
      - *id006
      Policies: *id007
      Capabilities:
        V2_0: true
    Application:
      Organizations:
EOF

# 5. Dynamically add all Application Orgs to DefaultChannel
# We grep for anchors that aren't the orderer (id006)
# We remove the '- ' from the start of the line, replace '&' with '*', and indent for the profile
ls "${ORGS_DIR}"/*.yaml | sort | xargs grep -h "&id" | grep -v "&id006" | sed 's/^- //' | sed 's/&/*/' | sed 's/^/      - /' >> "${OUTPUT}"

# 6. Final Polish for DefaultChannel
cat >> "${OUTPUT}" <<EOF
      Policies: *id009
      Capabilities:
        V2_5: true
EOF

echo "✅ Configuration assembled successfully at ${OUTPUT}"
