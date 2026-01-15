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
- [x] **Phase 7: Asset Marketplace** (Soft Deletes, IPFS Integration)

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
*   **`add-org.sh`**:
    *   **Automation**: The "Org Factory." Automatically determines the next unique monotonic ID, provisions a new CA, registers identities, and performs the multi-signature "Admin Dance."
    *   **Logging**: Detailed logs are stored in `docs/logs/` and history is tracked in `docs/logs/org_index.history`.
    *   **Example**: `./network/scripts/add-org.sh`
*   **`freeze-org.sh <num>`**:
    *   **Governance**: The "Consortium Lockout." Mandatory first step for removal. Restricts transaction submission while keeping history.
*   **`remove-org.sh <num>`**:
    *   **Governance**: The "Permanent Excise." Destructive operation. Requires organization to be frozen first. Wipes data, crypto material, and logs the excision to the immutable lifecycle log.
*   **`add-peer.sh <name> <org>`**: 
    *   **Automation**: Registers node with CA, issues TLS certs, and dynamically injects a new peer service into `docker-compose.yaml` with smart port allocation.
*   **`add-orderer.sh`**:
    *   **Consensus**: Scales the Raft cluster by provisioning a new orderer node. Automatically handles crypto generation, config injection (Consenter/Address), and `osnadmin` channel joining.
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
- **Global TLS CA Architecture**: Implements a dedicated TLS Certificate Authority (`ca_tls` on port 5054) acting as the single root of trust for transport security. This enables **Zero-Touch Scaling**, allowing new organizations to instantly communicate with existing peers without manual certificate swapping.
- **Fabric CA Integration**: Dynamic identity management with dedicated CAs for Org1 and Orderer.
- **Node OUs**: Automated role identification (Admin vs Peer vs Client).
- **CouchDB State Database**: Supports complex JSON queries and indexing.
- **Rich Query Support**: Search assets by any attribute using standard CouchDB selectors.
- **CaaS Workflow**: Chaincode runs as an external service for instant development cycles.
- **Mutual TLS**: Enforced across all boundaries with host-validated certificates.
- **Modern Channeling**: Uses `osnadmin` and Application Channel Participation.
- **Modular Infrastructure**: Horizontal splitting by organization (Found in `network/compose/`) for independent scaling.

---

## 📂 Project Logs & Audit Trail
Platform execution history is centrally managed in `docs/logs/`:
- **`org_lifecycle.log`**: Unified audit trail for all governance events (Freeze, Remove, Add).
- **`org_index.history`**: Monotonic index tracker for organization IDs.
- **`add-org_*.log`**: Complete execution traces for every organization provisioning event.

---

## 🔌 Network Port Allocation Strategy

To ensure zero collisions between Organizations and Peers running on the same host, we use a strict calculation formula based on `ORG_NUM` and `PEER_NUM`.

### Core Infrastructure Ports

| Service | Port | Description |
| :--- | :--- | :--- |
| **Backend API** | 8080 | REST Gateway for client applications |
| **Chaincode (CaaS)** | 9999 | External Smart Contract Service |
| **Orderer Listen** | 7050 | Raft Consensus Protocol |
| **Orderer Admin** | 7053 | Channel Participation API |
| **TLS CA** | 5054 | Root of Trust for Transport Layer Security |
| **Orderer CA** | 9054 | Identity Provider for Ordering Service |

### Dynamic Organization Ports

**Base Formula**: `Base Offset = (ORG_NUM - 1) * 1000`

| Service | Internal Port | Mapped Port Formula | Org1 Example | Org2 Example | Org3 Example* |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Org CA** | 7054 | `7054 + Base` | **7054** | **8054** | **10054** |
| **Peer Listen** | 7051 | `7051 + Base + (Peer*100)` | **7051** | **8051** | **9051** |
| **Peer CouchDB** | 5984 | `5984 + Base + (Peer*100)` | **5984** | **6984** | **7984** |
| **Peer Ops** | 9443 | `9443 + Base + (Peer*100)` | **9443** | **10443**| **11443**|

### Orderer Scaling Strategy
Orderer ports follow a `+100` offset per node:
*   **Orderer (Base)**: Listen `7050`, Admin `7053`.
*   **Orderer2**: Listen `7150`, Admin `7153`.
*   **Orderer3**: Listen `7250`, Admin `7253`.

> **⚠️ Reserved Port Exception**: The port range **9000-9999** is reserved for the Orderer CA (9054) and Chaincode (9999).
> Therefore, **Org3 CA** skips `9054` and is assigned `10054`. Peer ports for Org3 still use the `9000` range (e.g., 9051) as they do not collide with 9054/9999.

### Peer Expansion Ports (Same Org)
When adding extra peers to an organization (e.g., `Peer1`), add `100` to the peer ports:
*   **Org1 Peer1**: Listen `7151`, Couch `6084`.
*   **Org1 Peer2**: Listen `7251`, Couch `6184`.
