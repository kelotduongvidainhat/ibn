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

## 4. How to Manage Orderers (Dynamic Scaling)
The Ordering Service is designed for horizontal elasticity:

1.  **Add a Node**: Use `./network/scripts/add-orderer.sh`. This automatically handles CA registration, local enrollment, and the "config-update" logic required to add a new consenter to the Raft cluster.
2.  **Remove a Node**: Use `./network/scripts/remove-orderer.sh`. This safely removes the node from the metadata, wipes its infrastructure, and recalculates the cluster quorum.
3.  **Governance (Odd vs Even)**: Raft requires an odd number of nodes for optimal fault tolerance. The toolkit will warn you if a removal leaves the cluster in an even-numbered state.

## 5. Raft Governance: Odd vs Even Order

When scaling the cluster, the **number of nodes** is critical for Fault Tolerance.

| Nodes | Quorum (N/2 + 1) | Fault Tolerance (Nodes you can lose) |
| :--- | :--- | :--- |
| **1** | 1 | 0 |
| **2** | 2 | 0 |
| **3** | 2 | **1** |
| **4** | 3 | 1 |
| **5** | 3 | **2** |
| **6** | 4 | 2 |
| **7** | 4 | **3** |

### ⚠️ The "Even Order" Trap
*   **No Gain in Reliability**: A 2-node cluster has the same fault tolerance as a 1-node cluster (0 nodes). A 4-node cluster has the same as a 3-node cluster (1 node).
*   **Increased Risk**: Adding an even-numbered node increases the probability of hardware failure without increasing the network's ability to survive a failure.
*   **Recommendation**: Always aim for an **ODD** number of orderers (3, 5, or 7) to maximize stability and efficiency.

## 6. How to Create/Add an Orderer (Logic)

1. **CA Setup**: Usually, there is a dedicated CA for the Orderer Organization.
2. **Channel Genesis**: The very first block (Block 0) is created by `configtxgen`. It defines the consensus cluster.
3. **Join Proposal**: The Orderer admin uses the `osnadmin` command to "Start" the channel on the Orderer node.
4. **Volume Persistence**: Like peers, orderers need a persistent volume to store the chain of blocks.
