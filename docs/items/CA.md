# Item: Certificate Authority (CA)

**Fabric CA** is the "Passport Office" of the network. It manages the lifecycle of crypto-identities (Enrollment, Registration, Revocation).

## 1. Definition
The CA is a server that issues X.509 certificates. It is part of the **PKI (Public Key Infrastructure)** that makes Fabric a *permissioned* blockchain.

## 2. Key Attributes

| Attribute | Description |
| :--- | :--- |
| **CA Admin** | The bootstrap user created when the CA starts. |
| **Registrar** | An identity with the power to register *new* users. |
| **TLS Enabled** | Ensures communication with the CA is encrypted. |
| **LDAP Integration** | Ability to connect to corporate user directories (Production only). |

## 3. Core Workflow

1.  **Register**: The `orgadmin` tells the CA: *"Let 'peer0' join the network."* The CA generates a **Secret (Password)**.
2.  **Enroll**: 'peer0' uses that password to talk to the CA and says: *"Gimme my certificates."*
3.  **Governance**: The CA signs the certificates, effectively saying: *"I vouch for this peer."*

## 4. Relevance to Scaling (add-org)
In a truly decentralized network, **each Organization should own its own CA.**
- In our `add-org.sh` script, we launch a new CA container for every Org.
- This creates **Administrative Isolation**: Org1 cannot issue certificates for Org2. This is the cornerstone of multi-party trust.
