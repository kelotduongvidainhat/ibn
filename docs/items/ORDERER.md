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

The IBN platform supports dynamic horizontal scaling of the ordering service.

1. **Automation**: Use `./network/scripts/add-orderer.sh` or Option 5 in `ibn-ctl`.
2. **Horizontal Expansion**: Unlike static networks, you can add new orderer nodes to a running cluster without downtime.
3. **The "Admin Dance"**: The script fetches the current channel config, adds the new node's TLS certificate to the `Consenters` and `OrdererAddresses` lists, and submits the update.
4. **Channel Participation**: Once the config is updated, the new container is joined via the `osnadmin` API.

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
