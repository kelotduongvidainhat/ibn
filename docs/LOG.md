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
**Final Status**: Network migrated to CouchDB. Rich Queries enabled and verified via Backend API. Automation toolkit updated for database orchestration.
