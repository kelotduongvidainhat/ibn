# 🌐 IBN-Platform: Enterprise Blockchain Backbone

A production-grade Hyperledger Fabric platform designed for rapid deployment, horizontal scaling, and automated governance. This is the **Infrastructure Engine** for multi-application consortiums.

---

## � Features Enabled
- **Global TLS CA Architecture**: Implements a dedicated TLS Certificate Authority (`ca_tls` on port 5054) acting as the single root of trust for transport security. This enables **Zero-Touch Scaling**, allowing new organizations to instantly communicate with existing peers without manual certificate swapping.
- **Fabric CA Integration**: Dynamic identity management with dedicated CAs for Org1 and Orderer.
- **Node OUs**: Automated role identification (Admin vs Peer vs Client).
- **CouchDB State Database**: Supports complex JSON queries and indexing.
- **Rich Query Support**: Search assets by any attribute using standard CouchDB selectors.
- **CaaS Workflow**: Chaincode runs as an external service for instant development cycles.
- **Mutual TLS**: Enforced across all boundaries with host-validated certificates.
- **Manual Governance Toolkit**: Provides `add-org.sh`, `remove-org.sh`, `add-orderer.sh`, and `create-channel.sh` for one-button cluster management.
- **Modern Channeling**: Uses `osnadmin` and Application Channel Participation for dynamic provisioning without network restarts.
- **Modular Infrastructure**: Horizontal splitting by organization (Found in `network/compose/`) for independent scaling.
- **Modular Governance Registry**: Moving away from monolithic configuration. Each organization is an independent module in the `network/config/orgs/` registry, dynamically assembled by an automated engine.

---

## 🚀 The Superadmin Toolkit (`ibn-ctl`)
The `ibn-ctl` script is your primary interface for network operations. 

### 1. Scaling Commands
*   **`add-org.sh`**:
    *   **Automation**: The "Org Factory." Handles CA bootstrap, enrollment, peer startup, and consortium-wide configuration updates in a single automated flow.
*   **`remove-org.sh <num>`**:
    *   **Governance**: The "Permanent Excise." Destructive operation. Requires organization to be frozen first. Scans all channels for recursive removal and wipes infrastructure.
*   **`add-peer.sh <name> <org>`**: 
    *   **Automation**: Registers node with CA, issues TLS certs, and dynamically injects a new peer service into modular compose files.
*   **`add-orderer.sh`**:
    *   **Consensus**: Scales the Raft cluster by provisioning a new orderer node. Automatically handles crypto generation, config injection, and `osnadmin` joining.
*   **`remove-orderer.sh`**:
    *   **Consensus**: Safely decommissioning a Raft node. Performs channel configuration updates to remove the consenter from metadata before wiping the container.
*   **`create-channel.sh <name>`**:
    *   **Provisioning**: Zero-restart application channel creation. Joins all active Orderers and Peers to the new partition.
*   **`upgrade-cc.sh <name> <channel>`**:
    *   **Lifecycle**: The "Atomic Upgrader." Automatically increments version/sequence, repackages chaincode, installs on all peers, and coordinates a global rollout.
*   **`sync-anchors.sh <org_num> <channel>`**:
    *   **Discovery**: Updates the channel configuration to set the specified Org's peer as an Anchor. Required for cross-organization communication and private data gossip.
*   **`audit-channel.sh <channel>`**:
    *   **Governance**: The "Governance Inspector." Generates a deep-audit report of channel membership, anchor peer health, consensus rules, and committed chaincode lifecycle.

### 2. Lifecycle & Monitoring
*   **`mass-approve.sh` & `mass-commit.sh`**:
    *   **Scale**: Automates chaincode updates across all organizations in a single step—critical for large consortiums.
*   **`network-health.sh`**:
    *   **Diagnostics**: Checks ledger synchronization and block heights across every node in the network.
*   **`network-resource-monitor.sh`**:
    *   **Performance**: Real-time CPU/RAM/Network dashboard grouped by Organization.
*   **`org-logs.sh <org_num>`**:
    *   **Observability**: The "Log Aggregator." Streams and merges logs from all containers belonging to a specific organization (Peer, CA, CouchDB) into a single labeled view.
*   **`profile-gen.sh`**:
    *   **Integration**: Generates portable Connection Profile JSONs for app development.

### 3. Backend Admin API
The network management toolkit is exposed via REST API for remote integration:
*   `GET  /api/assets` - List all assets
*   `GET  /api/admin/health` - Execute network health check
*   `GET  /api/admin/resources` - Fetch real-time docker metrics
*   `POST /api/admin/approve` - Trigger batch chaincode approval
*   `POST /api/admin/commit` - Trigger batch chaincode commit
*   `POST /api/admin/channels` - Provision a new application channel dynamically
*   `POST /api/admin/upgrade` - Execute an atomic, multi-org chaincode upgrade

### 4. Cleanup & Maintenance
*   **`network-down.sh`**: Safely teardowns all containers, wipes persistent volumes, and resets the cryptographic state.

---

## 📂 Project Logs & Audit Trail
Platform execution history is centrally managed in `docs/logs/`:
- **`org_lifecycle.log`**: Unified audit trail for all governance events (Freeze, Remove, Add).
- **`org_index.history`**: Monotonic index tracker for organization IDs.
- **`retired_orgs.list`**: Registry of permanently removed organization IDs.
- **`add-org_*.log`**: Complete execution traces for every organization provisioning event.
