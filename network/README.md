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

## 📜 Role-Based Access (NodeOUs)
We use Node OUs to distinguish participants:
- **Admin**: Authorized to delete assets or upgrade chaincode.
- **Peer**: Authorized to endorse transactions.
- **Client**: Authorized to submit transactions.

These roles are embedded in the X.509 certificates and checked by the Smart Contract.
