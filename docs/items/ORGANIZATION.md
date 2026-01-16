# Item: Organization (The Stakeholder)

An **Organization** (commonly called a "Member") represents a legal entity or a distinct group in the network.

## 1. Definition
The Organization is the "Owner" of the Peers. It handles governance, membership, and signing authority. In Fabric, an Org is technically defined by its **MSP (Membership Service Provider)**.

## 2. Key Attributes (Properties)

| Attribute | Description |
| :--- | :--- |
| **MSP ID** | The unique string name (e.g., `Org1MSP`) that identifies the org in the channel configuration. |
| **Root/Intermediary CA** | The "Root of Trust." Any certificate signed by this CA is considered a valid member of this Org. |
| **Admins** | A set of high-privilege certificates that can sign "Channel Updates" (like adding new members). |
| **Organizational Units (OUs)** | Roles defined inside the Org (e.g., separating "Peers" from "Clients"). |

## 3. Core Roles & Functions

### A. Trust Anchor
The Org provides the cryptographic proof that a node or user belongs to them. Without an Org, a Peer cannot be trusted.

### B. Governance & Signing
Most network changes require a **Majority** of Organizations to sign. 
- *Adding an Org*: Org1 and Org2 must both sign.
- *Upgrading Code*: Org1 and Org2 must both approve.

### C. Endorsement Policy
The "Rules of the Game." For example: "For a transaction to be valid, we need signatures from both `Org1` AND `Org2`."

## 4. How to Create/Add an Organization (Logic)

To add an Organization to a running network:
1. **Bootstrap CA**: Start a dedicated Certificate Authority for the new Org.
2. **Generate Definition**: Use `configtxgen` to create a `definition.json`. This includes the Org's Root Cert and Policies.
3. **Channel Update (The Dance)**:
    - Get current channel config.
    - Insert the new Org's JSON definition.
    - Get signatures from the **Admins** of existing Orgs.
    - Submit the update to the Orderer.
4. **Provision Peers**: Once the channel "knows" the Org exists, the Org can now start its Peers and join the channel.

## 5. Automated Organization Scaling (The "Org Factory")
The IBN platform automates the complex "Admin Dance" required to expand the consortium:

1. **Automation**: Use `./network/scripts/add-org.sh` or Option 3 in `ibn-ctl`.
2. **Monotonic ID Strategy**: The platform automatically determines the next unique ID (Org2, Org3, etc.) to ensure no naming collisions.
3. **Automated Governance**: The script handles the complete lifecycle:
    - Starts the new Org's CA.
    - Generates the MSP definition.
    - Performs the manual "config-update" logic automatically inside the `cli` container.
    - Collects necessary signatures and submits the transaction.
4. **Member Readiness**: Automatically joins the new Org's first peer and configures it to be ready for transactions.
