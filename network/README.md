# Fabric Network Configuration (Fabric CA Bootstrap)

This directory contains the production-grade configuration for the Hyperledger Fabric MVP network using **Certificate Authorities** for dynamic identity management.

## 🧱 Network Topology

```text
⠿ fabric_test (Docker Network)
┃
┣━━ 🔐 ca_org1 (CA for Org1) ──────────▶ Port 7054
┣━━ 🔐 ca_orderer (CA for Orderer) ─────▶ Port 9054
┃
┣━━ 📦 orderer.example.com (Ordering Node)
┃   ┣━━ 🔌 7050: Consensus/Tx
┃   ┣━━ 🔌 7053: Admin (osnadmin)
┃   ┗━━ 📜 TLS: Issued by ca_orderer (SAN: orderer.example.com)
┃
┣━━ 📦 peer0.org1.example.com (Endorsing Node)
┃   ┣━━ 🔌 7051: Peer/Gossip
┃   ┣━━ 🔌 7052: Chaincode Callback (CaaS)
┃   ┗━━ 📜 TLS: Issued by ca_org1 (SAN: peer0.org1.example.com)
┃
┗━━ 📦 cli (Administrative Tools)
    ┗━━ 🔑 Identity: Admin@org1.example.com (Enrolled via CA)
```

## 📂 Key Files

- **`docker-compose.yaml`**: defines CA services, Orderer, Peer, and CLI.
- **`configtx.yaml`**: Channel definitions and MSP policies (Reader/Writer/Admin).
- **`scripts/bootstrap-ca.sh`**: The master orchestrator.
- **`scripts/enroll-identities.sh`**: Interacts with `fabric-ca-client` to issue certificates.
- **`scripts/deploy-caas.sh`**: Chaincode lifecycle automation.

## 🚀 Setup Workflow

### Automated Setup
The recommended way to start is:
```bash
./network/scripts/bootstrap-ca.sh
```

### What `bootstrap-ca.sh` do?
1. **Cleanup**: Stops previous containers and wipes `organizations/` data.
2. **CA Startup**: Launches `ca_org1` and `ca_orderer`.
3. **Enrollment**: Runs `enroll-identities.sh` to fetch certificates for all nodes and the admin user.
4. **MSP Setup**: Configures NodeOUs (`config.yaml`) in every MSP folder.
5. **Genesis**: Generates the channel block using `configtxgen`.
6. **Join**: Uses `osnadmin` and `peer channel join` to establish the network.

## 🛠️ Superadmin Toolkit

This network includes advanced scripts for managing nodes and scaling without restarting the entire fabric:

- **`scripts/add-peer.sh <peer_id> <org_name>`**: 
    - Registers/Enrolls a new peer identity with the Fabric CA.
    - Dynamically injects the peer service into `docker-compose.yaml`.
    - Automatically calculates unique ports to avoid collisions.
- **`scripts/remove-peer.sh <peer_id> <org_name>`**: 
    - Stops and removes the peer container and volumes.
    - Removes the service definition from `docker-compose.yaml`.
    - Cleans up filesystem identities.
- **`scripts/peer-join-channel.sh <peer_id> <org_name> <channel_name>`**:
    - High-level script to join any provisioned peer to any existing channel.
- **`scripts/network-down.sh`**:
    - Performs an exhausted cleanup of all Fabric containers, volumes, and cryptographic material.

## 🏢 Scaling the Network (Org Factory)

The network is designed to be extensible. Adding a new organization involves:
1. Creating a new CA.
2. Generating a new Org MSP definition.
3. Updating the channel configuration via a "Config Update Dance" (transaction update).
4. Joining the new Org's peers.

*Refer to `addOrg3.sh` in the root for a blueprint of this process.*

## 📜 Role-Based Access (NodeOUs)
...
