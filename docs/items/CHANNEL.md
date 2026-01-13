# Item: Channel (The Private Network)

A **Channel** is a private "tunnel" or subnet between specific Organizations.

## 1. Definition
Transactions happening in Channel A are completely invisible to Peers in Channel B. It is the primary way Fabric provides privacy and data isolation.

## 2. Key Attributes (Properties)

| Attribute | Description |
| :--- | :--- |
| **Channel ID** | The unique string name (e.g., `mychannel`). |
| **Policies** | The rules for modifying the channel (e.g., "Need MAJORITY of Admins to add a member"). |
| **Capabilities** | The version of Fabric features enabled (e.g., `V2_5`). |
| **World State** | The current value of all assets on this channel. |

## 3. Core Roles & Functions

### A. Data Isolation
Even if Org1 and Org2 are on the same physical server, their data is isolated into different databases if they are in different channels.

### B. Shared Ledger
Every Peer joined to the same channel will eventually have an identical copy of the blockchain (the History) and the World State (the Current Values).

### C. Governance Ledger
The first block of the channel (Block 0) and any subsequent configuration blocks (Blocks 1, 2, etc.) act as the "Living Constitution" of the network.

## 4. How to Manage a Channel (Logic)

1. **Creation**: Start with a Genesis block (Block 0).
2. **Joining Node**: Every Orderer and Peer must explicitly join the channel.
3. **Updating Config**: 
    - Fetch the latest config block.
    - Transform via JSON.
    - Compute Delta.
    - Collect Signatures.
    - Submit update.
4. **Deploying Logic**: Chaincode is deployed *at the channel level*. You install it on Peers, but you **Commit** it to the Channel.
