# Item: Service Discovery & Gossip

**Service Discovery** is the mechanism that allows client applications to dynamically learn about the network topology and endorsement requirements.

## 1. Definition
Instead of hardcoding every peer address in the client, Service Discovery provides a "Query API" on the peer that returns the current state of the channel.

## 2. Key Attributes (The "Discovery" Metadata)

| Attribute | Description |
| :--- | :--- |
| **Anchor Peers** | The designated nodes for cross-organization communication. These are the entry points for the Discovery service. |
| **Endorsement Layouts** | Combinations of peers that can satisfy a policy (e.g., "Any 2 peers from {Org1, Org2, Org3}"). |
| **Chaincodes** | A list of which peers have which chaincode versions installed and running. |
| **MSP Config** | The TLS root certificates for every organization (needed so the client can verify the peers it discovers). |

## 3. Core Functions

### A. Topology Discovery
The client learns about every peer joined to the channel, their MSP IDs, and their endpoint addresses.

### B. Endorsement Discovery
The client asks: *"What peers do I need to sign this transaction?"* Discovery returns a list of peers that satisfy the current lifecycle and endorsement policies.

### C. Load Balancing
If an Org has 10 peers, Service Discovery identifies which ones are online and healthy, preventing the client from sending requests to a "dead" node.

## 4. Relevance to Network Scaling (add-org)

When adding a new Organization, Service Discovery is configured via the **Anchor Peer Transaction**:
1.  **Identity**: The new Org joins.
2.  **Announcement**: We submit a channel update setting the `AnchorPeers` for the new Org.
3.  **Discovery**: Existing organizations' Discovery services fetch the new config and suddenly "see" the new Org.
4.  **Client Update**: The user's backend automatically starts sending transaction proposals to the new Org without any code changes.
