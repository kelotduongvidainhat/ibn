# Naming & Automation Conventions

To ensure the reliability of our automation scripts (`add-org.sh`, `add-peer.sh`) and maintain a predictable network topology, the following normalized naming standards are enforced across the network.

## 1. Organizations & MSPs

We use a strictly numeric suffix for organizations to allow for deterministic port calculation and script logic.

| Entity | Pattern | Example (Org 4) |
| :--- | :--- | :--- |
| **Organization Name** | `org<n>` | `org4` |
| **Domain Name** | `org<n>.example.com` | `org4.example.com` |
| **MSP ID** | `Org<n>MSP` | `Org4MSP` |

> **Automation Note:** Scripts like `add-org.sh` use `grep -o '[0-9]\+'` to extract the number from the organization name to derive these values dynamically.

## 2. Infrastructure & Ports

Port mapping follows a "Salted Offset" logic to prevent collisions and simplify firewall pathing.

### CA (Certificate Authority)
- **Primary Port:** `7054 + (n-1) * 1000`
- **Exceptions:** If the calculation results in `9054` (reserved for Orderer), it is pushed to `10054`. If $\ge 10054$, an additional `1000` is added.
- **Operations Port:** `10000 + Primary Port`

### Peers (Gossip & Operations)
Peers use a dynamic "Next Available" search starting from a base offset:
- **Base GRPC:** Start scanning from `7051` across all known peers in `docker-compose.yaml`.
- **Base Operations:** Start scanning from `9443`.

## 3. Persistent Identities

Standardized names for administrative and node identities ensure that enrollment paths are consistent.

| Identity Role | Name | Enrollment Home Path |
| :--- | :--- | :--- |
| **Org Admin** | `orgadmin` | `.../organizations/peerOrganizations/<domain>/users/Admin@<domain>/msp` |
| **Peer Node** | `peer<m>` | `.../organizations/peerOrganizations/<domain>/peers/peer<m>.<domain>/msp` |

## 4. Why Normalization?

1.  **Script Efficiency**: Allows `add-org.sh` to sign channel updates for N organizations without manual path definitions.
2.  **Idempotency**: Allows scripts to "detect" if an organization already exists by checking for standardized directory names or volume keys.
3.  **Cross-Org Communication**: Peer certificates are generated with SANs (Subject Alternative Names) that follow the `peer<m>.<domain>` pattern, which is critical for TLS handshakes in a multi-org environment.

---
*Last Updated: 2026-01-13*
