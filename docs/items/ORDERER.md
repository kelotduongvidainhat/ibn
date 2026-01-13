# Item: Orderer (The Sequencing Service)

The **Orderer** (Ordering Service) is the "Referee" of the network. It ensures all peers receive the same transactions in the same order.

## 1. Definition
The Orderer does not execute smart contracts. It only packages transactions into blocks and distributes them to the Peers. It ensures consistency across the whole network.

## 2. Key Attributes (Properties)

| Attribute | Description |
| :--- | :--- |
| **Consensus Type** | Usually **Raft** (etcdraft). It uses a "Leader/Follower" model to ensure fault tolerance. |
| **Consenters** | The list of Orderer nodes that are allowed to participate in the Raft cluster. |
| **Batch Timeout** | How long to wait before cutting a block (e.g., `2s`). |
| **Batch Size** | How many transactions fit into a single block (e.g., `10` or `512 KB`). |

## 3. Core Roles & Functions

### A. Sequencing
It receives transactions from various clients, puts them in a strict chronological order, and wraps them in a Block.

### B. Channel Participation
The Orderer manages the "Membership List" for every channel. When you run `osnadmin channel join`, you are telling the Orderer to start and manage a specific blockchain.

### C. Distribution (Broadcast)
Peers connect to the Orderer via gRPC to "Subscribe" to block updates. As soon as a block is cut, the Orderer sends it to the Peers.

## 4. How to Create/Add an Orderer (Logic)

1. **CA Setup**: Usually, there is a dedicated CA for the Orderer Organization.
2. **Channel Genesis**: The very first block (Block 0) is created by `configtxgen`. It defines the consensus cluster.
3. **Join Proposal**: The Orderer admin uses the `osnadmin` command to "Start" the channel on the Orderer node.
4. **Volume Persistence**: Like peers, orderers need a persistent volume to store the chain of blocks.
