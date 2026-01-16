# 📋 [COMPLETED] Plan: Organization Scaling & Lifecycle Hardening

This document outlines the strategy for refining the existing Organization management scripts to ensure enterprise-grade stability and security.

## 🎯 Objectives
1.  **Monotonic ID Integrity**: Prevent the "Zombie ID" problem where a removed Org ID is accidentally reused, leading to cryptographic collisions and ledger inconsistencies.
2.  **Clean Room Removal**: Ensure that 'removing' an organization leaves zero traces in SDK connection profiles and project configuration files.
3.  **Multi-Channel Support**: Future-proof the removal logic to handle organizations residing in multiple channels.

## 🛠️ Key Components

### 1. The Retired ID Registry (`retired_orgs.list`)
*   **Location**: `docs/logs/retired_orgs.list`
*   **Logic**: 
    *   `remove-org.sh` will append the removed Org ID to this file.
    *   `add-org.sh` will be updated to check this list and skip any globally retired IDs.

### 2. Automatic SDK Reconciliation
*   **Trigger**: Final step of `remove-org.sh`.
*   **Action**: Invoke `profile-gen.sh` to scrub the removed Org from `backend/connection.json` and internal profiles.

### 3. State-Aware Removal (Safety Locks)
*   **Refinement**: Before removing from the channel config, the script must verify that all containers associated with that Org ID are actually stopped.
*   **Validation**: Add a check to verify the Org is effectively "Frozen" (ForbiddenMSP) in the ledger before allowing the permanent excise.

### 4. Recursive Channel Cleanup
*   **Logic**: Update removal scripts to iterate through all known channels (discovered via `peer channel list`) rather than just the default `mychannel`.

## 📈 Impact
*   **Zero Collisions**: Guaranteed monotonic growth.
*   **SDK Stability**: Client applications won't crash trying to connect to non-existent peers.
*   **Governance Proof**: Provides a clear, immutable audit trail of the consortium's expansion and contraction.
