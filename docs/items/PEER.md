# Item: Peer (The Endorser & Committer)

A **Peer** is the fundamental unit of a Hyperledger Fabric network. It is a node that hosts the ledger and smart contracts (chaincode).

## 1. Definition
The Peer is the "worker" of the blockchain. While the Orderer manages the sequence of transactions, the Peer is where the actual data lives and where the code (Chaincode) execution is validated.

## 2. Key Attributes (Properties)

| Attribute | Description |
| :--- | :--- |
| **Identity (MSP)** | Every peer has an X.509 certificate issued by its Org's CA. It identifies them as a "Peer" via NodeOUs. |
| **Address** | The gRPC endpoint (e.g., `peer0.org1.example.com:7051`) used for communication. |
| **Chaincode Address** | A specific port (usually `7052`) used by the peer to communicate with the Chaincode container (CaaS). |
| **State Database** | Usually **LevelDB** (default) or **CouchDB** (for rich JSON queries). |
| **Ledger (Blockchain)** | A local copy of the channel's transaction history (stored in `/var/hyperledger/production`). |

## 3. Core Roles & Functions

### A. Endorsement (Execution)
When a client application wants to submit a transaction, it sends a proposal to the Peer. The Peer:
1. Simulates the transaction using its local smart contract.
2. If successful, "signs" the result.
3. Returns this "Endorsement" to the client.

### B. Committing (Validation)
Once a block of transactions is sent from the Orderer:
1. The Peer receives the block.
2. It validates that all transactions have enough signatures (Endorsement Policy).
3. It checks for "Double Spending" (MVCC conflicts).
4. If valid, it writes the changes to its local Ledger and State Database.

### C. Anchor Peer (Communication)
A specific peer designated as the point of contact for other Organizations. It allows different Orgs to "discover" each other via Gossip protocol. 

**Automation**: The IBN platform automatically synchronizes Anchor Peers using `./network/scripts/sync-anchors.sh` whenever a new Organization is added, ensuring immediate cross-org visibility.

## 5. Automated Scaling (The "Peer Factory")
The IBN platform simplifies peer management through automation:

1. **Automation**: Use `./network/scripts/add-peer.sh` or Option 4 in `ibn-ctl`.
2. **Auto-Discovery**: The toolkit automatically detects current peers and assigns the next logical name (e.g., `peer1`, `peer2`) and non-conflicting port (e.g., 7151, 7251).
3. **One-Button Deployment**: A single command handles registration, enrollment, container provisioning, channel joining, and **automatic chaincode installation**.
4. **Consistency**: Using the `ibn-ctl` ensures all peers within an organization share the same configuration, CouchDB state database, and external builder settings.

## 6. How to Create/Add a Peer (Logic)

To bring a peer online, you must:
1. **Register**: Tell the CA that a new identity named `peerX` exists.
2. **Enroll**: Fetch the MSP (Identity) and TLS (Communication) certificates.
3. **Provision Container**: Start a Docker container with:
    - Environment variables mapping to the certificates.
    - Volume mounts for persistent storage.
    - Port mappings for external access.
4. **Join Channel**: Fetch the Genesis block and submit a join proposal.
5. **Install Chaincode**: Copy the smart contract binary/package to the peer so it can execute it.
