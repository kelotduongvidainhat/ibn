# Fabric Network Configuration (Cryptogen Bootstrap)

This directory contains the essential configuration for the Hyperledger Fabric MVP network using static certificate generation (`cryptogen`).

## 🧱 Network Topology

```text
⠿ fabric_test (Docker Network)
┃
┣━━ 📦 orderer.example.com (Ordering Node)
┃   ┣━━ 🔌 7050: Consensus/Tx
┃   ┣━━ 🔌 7053: Admin (osnadmin)
┃   ┣━━ 📂 ./organizations/.../msp  ──▶ /var/hyperledger/orderer/msp
┃   ┗━━ 📂 ./organizations/.../tls  ──▶ /var/hyperledger/orderer/tls
┃
┣━━ 📦 peer0.org1.example.com (Endorsing Node)
┃   ┣━━ 🔌 7051: Peer/Gossip
┃   ┣━━ 🔌 7052: Chaincode Callback (CaaS)
┃   ┣━━ 📂 ./organizations/.../msp  ──▶ /etc/hyperledger/fabric/msp
┃   ┣━━ 📂 ./organizations/.../tls  ──▶ /etc/hyperledger/fabric/tls
┃   ┗━━ � ../builders/ccaas        ──▶ /opt/hyperledger/builders/ccaas
┃
┗━━ �📦 cli (Administrative Tools)
    ┣━━ 📂 ./organizations          ──▶ /opt/gopath/.../organizations
    ┣━━ 📂 ./channel-artifacts       ──▶ /opt/gopath/.../channel-artifacts
    ┣━━ 🔨 peer
    ┗━━ 🔨 osnadmin
```

## 📂 File Manifest

- **`crypto-config.yaml`**: Template for `cryptogen` to create X.509 certs & keys.
- **`configtx.yaml`**: Channel and Genesis block configuration.
- **`docker-compose.yaml`**: Service definitions for the node containers.
- **`scripts/bootstrap.sh`**: One-click automation for identity generation and channel setup.
- **`scripts/test-network.sh`**: Health check utility to verify node and channel status.
- **`scripts/deploy-caas.sh`**: One-click automation for CC install, approve, and commit.
- **`organizations/`**: (Generated) Root folder for all crypto material.
- **`channel-artifacts/`**: (Generated) Storage for the channel genesis block.

## 🚀 Setup Workflow

The easiest way to start the network is using the bootstrap script:

```bash
# From the project root
./network/scripts/bootstrap.sh
```

Alternatively, manual steps:

1. **Step 1: Generate Cryptography**
   ```bash
   ./bin/cryptogen generate --config=./network/crypto-config.yaml --output="network/organizations"
   ```

2. **Step 2: Generate Genesis Block**
   ```bash
   export FABRIC_CFG_PATH=${PWD}/network
   ./bin/configtxgen -profile Org1Channel -outputBlock ./network/channel-artifacts/mychannel.block -channelID mychannel
   ```

3. **Step 3: Start Services**
   ```bash
   docker-compose -f network/docker-compose.yaml up -d
   ```

4. **Step 4: Join Channel**
   Use the bootstrap script's logic or manual `osnadmin` calls via CLI.

## 🧪 Testing the Network

Verify everything is running correctly:
```bash
./network/scripts/test-network.sh
```

## 🛠 Features Enabled
- **CaaS Ready**: External builder `ccaas-builder` is mounted to the peer.
- **Modern Channeling**: Uses `osnadmin` and the Application Channel Participation API (No system channel).
- **Mutual TLS**: Enforced across all boundaries for maximum security.
