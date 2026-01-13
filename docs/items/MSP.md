# Item: Membership Service Provider (MSP)

**MSP** is the component that defines how identities are validated and what roles they hold. It turns "Certificates" into "Members."

## 1. Definition
The MSP is not a piece of software, but a **Configuration Structure** that tells a node: *"These are the people I trust, and this is how I know they belong here."*

## 2. Key Attributes (The MSP Folder)

| Component | Description |
| :--- | :--- |
| **cacerts** | The Root CA certificate (The ultimate source of truth for this Org). |
| **tlscacerts** | The Root CA for TLS connections. |
| **signcerts** | The node's individual identity certificate. |
| **keystore** | The node's private key (Must NEVER be shared). |
| **config.yaml** | Defines NodeOUs (Client, Peer, Admin, Orderer). |

## 3. Core Functions

### A. Authentication
When a transaction arrives, the MSP checks the signature against the `cacerts` to prove the sender is a valid member.

### B. Authorization (Roles)
The MSP uses **NodeOUs** to distinguish between a regular user (Client), a server (Peer), and an administrator (Admin).

## 4. Relevance to Scaling (add-org)
When adding an organization, you are essentially "registering the MSP" with the channel.
1.  **Preparation**: You create the MSP folder structure via the CA.
2.  **Admission**: You add the `MSPDir` and `ID` to the channel config.
3.  **Trust**: Once admitted, every other node in the network will now accept signatures from your Org's members.
