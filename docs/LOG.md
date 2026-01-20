# Transaction Log: Manual Organization Addition (Org2)

This document logs the manual steps taken to add a new organization (Org2) to the existing Hyperledger Fabric network (Org1).

## Phase 1: Identity Creation (Fabric CA)

1.  **Container Launch**: Added `ca_org2` to `docker-compose.yaml` and started it.
2.  **CA Admin Enrollment**:
    ```bash
    export FABRIC_CA_CLIENT_HOME=network/organizations/fabric-ca/org2
    fabric-ca-client enroll -u https://admin:adminpw@localhost:8054 --tls.certfiles .../ca-cert.pem
    ```
3.  **Identity Registration**:
    *   `peer0`: `fabric-ca-client register --id.name peer0 --id.secret peer0pw --id.type peer`
    *   `org2admin`: `fabric-ca-client register --id.name org2admin --id.secret org2adminpw --id.type admin`
4.  **MSP & TLS Enrollment**:
    *   Enrolled `peer0` for its identity MSP and TLS certificates.
    *   Enrolled `org2admin` for the administrator MSP.
5.  **NodeOU Configuration**: Created `config.yaml` to enable role-based identification (Client, Peer, Admin, Orderer).

## Phase 2: Configuration Update (The "Admin Dance")

1.  **Org Definition**: Generated JSON representation of Org2 using `configtxgen`.
    ```bash
    configtxgen -printOrg Org2MSP > channel-artifacts/org2.json
    ```
2.  **Channel Config Fetch**: Fetched the latest config block (Block 2) from the Orderer.
3.  **JSON Transformation**: Used `jq` to append the Org2 definition into the `Application` group of the channel config.
4.  **Compute Delta**: Computed the difference (update) between the old config and the new config.
5.  **Envelope Wrapping**: Wrapped the update into a standard Fabric transaction envelope.
6.  **Signature & Submission**:
    *   Signed by **Org1 Admin** (existing authority).
    *   Updated the channel: `peer channel update -f update_in_envelope.pb`

## Phase 3: Infrastructure & Integration

1.  **Peer Startup**: Added `peer0.org2.example.com` to `docker-compose.yaml` and started the container.
2.  **Channel Join**:
    ```bash
    ./network/scripts/peer-join-channel.sh peer0 org2 mychannel
    ```
3.  **Chaincode Installation**:
    *   Installed the `basic.tar.gz` package on `peer0.org2.example.com`.
4.  **Chaincode Approval**:
    *   Approved the chaincode definition for Org2:
    ```bash
    peer lifecycle chaincode approveformyorg --channelID mychannel --name basic ...
    ```
5.  **Chaincode Committing**:
    *   The chaincode definition was already committed, but now Org2's approval is registered, satisfying the "MAJORITY" policy for transactions involving Org2.

## Phase 4: Verification

1.  **InitLedger**: Invoked the contract to initialize data (required both Org1 and Org2 signatures for endorsement).
2.  **Cross-Org Query**: Verified that Org2 can successfully read assets created on the ledger.
    ```bash
    peer chaincode query -C mychannel -n basic -c '{"Args":["ReadAsset","asset1"]}'
    ```

---
**Status**: Org2 is fully integrated.

## Phase 5: Manual Organization Addition (Org3) - Scaling to 3 Orgs

1.  **Identity Foundation**: Created `ca_org3` and identities for `peer0.org3` and `Admin@org3.example.com`.
2.  **The "Majority" Admin Dance**: 
    - Fetched channel config (Block 9).
    - **MAJORITY Requirement**: Since the channel had 2 Orgs (Org1, Org2), the update required signatures from **both** before admission.
    - Orderer successfully processed the update.
3.  **Physical Integration**:
    - Peer `peer0.org3.example.com` joined `mychannel`.
    - Block height synchronized to current state.
4.  **Chaincode Lifecycle**:
    - Installed `basic_1.0` on Org3 Peer.
    - Approved definition for `Org3MSP`.
    - Verified `querycommitted` shows approvals from all 3 Orgs.

## Phase 6: Automated Scaling (The Org Factory)

1.  **Toolkit Creation**: Developed `network/scripts/add-org.sh` to automate the entire CA setup, identity enrollment, channel config update, and peer integration.
2.  **Dynamic Scaling**: Successfully scaled the network to **6 Organizations** using the automation script.
3.  **Cross-Org Consensus Test**:
    - **5 Orgs Scenario**: Verified that 3 signatures (Majority) are required to commit.
    - **6 Orgs Scenario**: Verified that the Majority requirement is exactly **4 signatures**.
    - **Empirical Proof**:
        - `assetX3` (3/6 signatures): **REJECTED**. Transaction submitted but asset not created in World State.
        - `assetX4` (4/6 signatures): **ACCEPTED**. Asset successfully stored and queried.
    - **Validation Proof**: Confirmed that transactions with insufficient signatures (3/6) are rejected by the peers' validation phase even if they pass the ordering phase.
## [2026-01-14] Governance & Lifecycle Automation
- **Implemented `freeze-org.sh`**: Developed a "soft-lock" governance tool that restricts an organization's access by updating channel policies to an unsatisfiable state.
- **Implemented Mandatory Two-Step Removal**: Enhanced `remove-org.sh` with a safety airlock. The script now enforces that an organization must be "Frozen" before it can be "Excised."
- **Infrastructure Purge**: `remove-org.sh` now automates the cleanup of Docker containers, volumes, `configtx.yaml` entries, and physical cryptographic material.

---
## Phase 7: The Superadmin Suite
1.  **Orchestration**: Developed `ibn-ctl` as a master entry point for both interactive and automated network management.
2.  **Lifecycle Automation**: Implemented `mass-approve.sh` and `mass-commit.sh` to handle concurrent chaincode updates for all 6 organizations.
3.  **Observability**: Added `network-health.sh` (Blockchain sync) and `network-resource-monitor.sh` (System metrics).
4.  **Backend Integration**: Exposed the entire toolkit via `/api/admin` endpoints in the Go backend.

---
**Final Status**: Network scaled to 6 Organizations. All nodes synchronized. Superadmin Toolkit fully implemented and documented.
**Key Achievement**: Moved from manual "Constitutional Surgery" to a fully automated, observable, and API-managed Multi-Org Consortium.
---
## Phase 8: Rich Queries & CouchDB Migration

1.  **State Database Upgrade**:
    - Migrated the entire network state database from LevelDB to **CouchDB**.
    - Provisions a dedicated CouchDB container for every peer (e.g., `couchdb0`, `couchdb.peer0.org2...`).
    - Enabled **Fauxton UI** access for visual ledger browsing.
2.  **Smart Contract Upgrade (v1.1)**:
    - Implemented `QueryAssets`: Generic function for complex JSON selectors.
    - Implemented `GetAssetsByColor`: Attribute-based search helper.
    - Implemented `GetAllAssets`: Full collection listing.
3.  **Backend API Expansion**:
    - Exposed `GET /api/assets` and `GET /api/assets/query` endpoints.
    - Updated `asset_handler.go` to handle JSON unmarshaling of result slices.
4.  **Troubleshooting & Hardening**:
    - **Port Shadowing**: Discovered and resolved an issue where a ghost local process on port 8080 was shadowing the Dockerized backend service.
    - **Peer Factory Update**: Hardened `add-peer.sh` to automatically calculate unique CouchDB ports and link them to new peers.

---
## Phase 7: Multi-Channel Orchestration & ICC

1.  **Isolated Channels**: Implemented `create-channel.sh` with profile support (`DefaultChannel`, `TwoOrgChannel`).
2.  **Multi-Tenant Backend**: Refactored the Go API to support parameterized routes (`/api/:channel/:ccname/...`), allowing a single backend to serve multiple isolated ledgers.
3.  **Inter-Channel Communication (ICC)**: 
    - Added `ReadAssetFromChannel` to the smart contract using the `InvokeChaincode` API.
    - Verified that Org1 can securely bridge from `mychannel` to `channel2` to verify asset state.
4.  **Security Boundaries**: Proved that Org3 (not a member of `channel2`) is physically blocked from cross-channel queries.

---
## Phase 8: Decentralized Storage (IPFS)

1.  **Consortium Sidecar**: Integrated an **IPFS (Kubo)** node as a shared infrastructure component.
2.  **Hybrid Ledger Model**: 
    - Extended the `Asset` struct to include `FileCID` and `FileName`.
    - Assets on-chain now store Content Identifiers (CIDs) pointing to off-chain data.
3.  **Automated Uploads**: Developed a Go-based IPFS client in the backend to handle `multipart/form-data` uploads, generating CIDs and committing them to the ledger in a single atomic transaction.

---
## Phase 9: Enterprise Security (ABAC)

1.  **Attribute Injection**: Updated `enroll-identities.sh` to register users with functional roles (`admin`, `manager`, `viewer`) inside the X.509 ECerts.
2.  **Smart Contract Guards**:
    - Implemented `hasRole` helper in the chaincode using the `cid` (Client Identity) library.
    - Restricted `InitLedger` to `admin`.
    - Restricted `CreateAsset` to `admin` or `manager`.
3.  **Security Verification**: Created `test-abac.sh` to prove that a user with the `viewer` role is rejected by the peer when attempting to mutate state.
4.  **Resource Delta Profiling**:
    - Developed `network-audit.sh` to capture "before/after" snapshots of RAM, Disk, and Container counts.
    - Integrated with `ibn-ctl` via `snap` and `diff` commands.
    - Verified that adding a single Peer+CouchDB consumes ~123MB of RAM and 1 extra Data Volume.

---
## Phase 10: Environment Hardening & 3-Org Bootstrap

1.  **Dependency Resolution**:
    - Identified and resolved missing host dependencies (`jq`, `bc`, `python3-yaml`).
    - Successfully downloaded official Hyperledger Fabric binaries (v2.5.11) and CA binaries (v1.5.14) into the local project structure.
2.  **Docker Orchestration Fix**:
    - Debugged a critical "docker-credential-desktop" error caused by a legacy credential helper in the host config.
    - Reset `~/.docker/config.json` to allow native credential management, unblocking image pulls and builds.
3.  **3-Organization Bootstrap**:
    - Executed a successful `fresh-start.sh` sequence.
    - Provisioned a consortium with **3 Organizations** (Org1, Org2, Org3) from scratch.
    - Automated channel creation (`mychannel`) and anchor peer synchronization.
4.  **CaaS Deployment (v1.0)**:
    - Packaged and committed the Chaincode-as-a-Service (basic) across all 3 organizations.
    - Verified synchronization with the Go Backend and Chaincode-Basic containers.
5.  **Health Verification**:
    - Confirmed all 12 containers (CAs, Peers, Orderer, CouchDBs, Backend) are stable.
    - Verified ledger synchronization across all 3 orgs at block height 9.

---
## Phase 11: Blockchain Observability (Block Visualizer)

1.  **Backend Extension**:
    - Created `BlockHandler` in the Go backend.
    - Integrated with `QSCC` (Query System Chaincode) to access ledger metadata.
    - Added routes for `GetChainInfo` (current height/hashes) and `GetBlockByNumber`.
2.  **Real-time Auditing**:
    - Verified block height tracking (Height: 9).
    - Verified architectural decoding of genesis (Block 0) and transaction blocks.
3.  **Deployment**:
    - Rebuilt the backend Docker container to pick up new observability endpoints.
    - Updated `ARCHITECTURE.md` and `ROADMAP.md`.

---
## Phase 12: Enterprise Governance (Certificate Revocation)

1.  **Revocation Workflow**:
    - Developed `revoke-identity.sh` to handle the full revocation lifecycle.
    - Integrated `fabric-ca-client revoke` and `gencrl` to manage the CA database and generate signed exclusion lists.
2.  **Channel-wide Enforcement**:
    - Implemented an automated "Admin Dance" to inject CRLs into the channel's MSP configuration.
    - Verified that revocation is cross-organization, requiring signatures from the consortium to admit the new CRL.
3.  **Toolkit Integration**:
    - Added a dedicated "Revoke Identity" option to the `ibn-ctl` master menu.
    - Updated documentation to reflect the new security protocol.
