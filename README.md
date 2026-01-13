# Hyperledger Fabric MVP (CaaS & Fabric CA)

This project implements a high-performance, production-grade Hyperledger Fabric network designed for rapid development using **Chaincode-as-a-Service (CaaS)** and **Fabric Certificate Authorities (CA)**.

## ✨ Quick Access
👉 **[Read the 5-Minute QUICKSTART.md](./QUICKSTART.md)**
🗺️ **[View the Project ROADMAP.md](./ROADMAP.md)**
🏛️ **[Review the Platform ARCHITECTURE.md](./ARCHITECTURE.md)**

## ✅ Project Status
- [x] **Phase 1: Planning & Setup** (Multi-CA Architecture)
- [x] **Phase 2: Network Infrastructure** (Dynamic Enrollment, Healthy Nodes)
- [x] **Phase 3: Smart Contract (CaaS)** (Go Contract, Dockerized Service)
- [x] **Phase 4: Backend API** (Fabric Gateway, REST Endpoints)
- [x] **Phase 6: Fabric CA Integration** (Mutual TLS, Authority-based Enrollment)
- [x] **Phase 5: Advanced Logic** (History, Transfers, Automated Scaling)
- [x] **Phase 6: Rich Queries & CouchDB** (CouchDB Migration, Selector Queries)
- [🚧] **Phase 7: Asset Marketplace** (Soft Deletes, IPFS Integration)

## 🏗️ Project Structure

```text
.
├── bin/                 # Fabric v2.5 binaries
├── builders/            # External builder for CaaS
├── network/             # Network YAMLs, CA config, and automation scripts
│   ├── scripts/         # bootstrap-ca.sh, enroll-identities.sh, deploy-caas.sh
│   └── packaging/       # connection.json and .tar.gz packages
├── backend/             # Go Gateway API (Gin Framework)
├── chaincode/           # Smart contract source code (Go)
│   ├── cmd/             # CaaS server wrapper entry point
│   └── Dockerfile       # Container definition for the CC service
└── README.md            # Overall project status
```

## 🕹️ Master Control
The entire network can be managed via the **ibn-ctl** Terminal Suite:
```bash
./ibn-ctl
```

## 🚀 Getting Started

### 1. Build & Start Network (Full 6-Org Build)
The recommended way to build the complete 6-organization network from scratch:
```bash
./fresh-start.sh
```

### 2. Build & Start Network (Minimal)
Run the automated bootstrap script to launch just Org1 and the Orderer:
```bash
./network/scripts/bootstrap-ca.sh
```

### 2. Deploy Chaincode
Install, approve, and commit the chaincode definition:
```bash
./network/scripts/deploy-caas.sh
```

### 3. Launch Chaincode Service
Start the external chaincode container:
```bash
docker-compose -f network/docker-compose.yaml up -d chaincode-basic
```

### 4. Verify
```bash
# Manual query via CLI
docker exec cli peer chaincode query -C mychannel -n basic -c '{"Args":["ReadAsset","asset1"]}'
```

## 🛠 Superadmin Toolkit

The network includes a suite of automation scripts for advanced operations and scaling:

### 1. Unified Setup & Deployment
*   **`fresh-start.sh`**: The "Big Bang" script. Fully wipes the network and automates the scaling to 6 organizations, deployment of chaincode, and startup of the Backend API.
*   **`bootstrap-ca.sh`**: The master setup script for a minimal network (Org1 + Orderer).
*   **`deploy-caas.sh`**: Handles the full Fabric lifecycle (Install -> Approve -> Commit) for Chaincode-as-a-Service.

### 2. Network Scaling
*   **`add-org.sh <num>`**:
    *   **Automation**: The "Org Factory." Provisions a new CA, registers identities, and performs the multi-signature "Admin Dance" to admit a new organization to the channel.
    *   **Example**: `./network/scripts/add-org.sh 4`
*   **`add-peer.sh <name> <org>`**: 
    *   **Automation**: Registers node with CA, issues TLS certs, and dynamically injects a new peer service into `docker-compose.yaml` with smart port allocation.
*   **`peer-join-channel.sh <name> <org> <channel>`**:
    *   **Logic**: Joins a provisioned physical peer to an active logical channel.

### 3. Lifecycle & Monitoring
*   **`mass-approve.sh` & `mass-commit.sh`**:
    *   **Scale**: Automates chaincode updates across all organizations in a single step—critical for large consortiums (e.g., our 6-Org setup).
*   **`network-health.sh`**:
    *   **Diagnostics**: Checks ledger synchronization and block heights across every node in the network.
*   **`network-resource-monitor.sh`**:
    *   **Performance**: Real-time CPU/RAM/Network dashboard grouped by Organization.
*   **`profile-gen.sh`**:
    *   **Integration**: Generates portable Connection Profile JSONs for app development.

### 4. Backend Admin API
The network management toolkit is exposed via REST API for remote integration:
*   `GET  /api/assets` - List all assets
*   `GET  /api/assets/query?query={...}` - Execute CouchDB Rich Query
*   `GET  /api/admin/health` - Execute network health check
*   `GET  /api/admin/resources` - Fetch real-time docker metrics
*   `POST /api/admin/approve` - Trigger batch chaincode approval
*   `POST /api/admin/commit` - Trigger batch chaincode commit

### 4. Cleanup & Maintenance
*   **`network-down.sh`**: Safely teardowns all containers, wipes persistent volumes, and resets the cryptographic state.

---

## 🏗 Features Enabled
- **Fabric CA Integration**: Dynamic identity management with dedicated CAs for Org1 and Orderer.
- **Node OUs**: Automated role identification (Admin vs Peer vs Client).
- **CouchDB State Database**: Supports complex JSON queries and indexing.
- **Rich Query Support**: Search assets by any attribute using standard CouchDB selectors.
- **CaaS Workflow**: Chaincode runs as an external service for instant development cycles.
- **Mutual TLS**: Enforced across all boundaries with host-validated certificates.
- **Modern Channeling**: Uses `osnadmin` and Application Channel Participation.
