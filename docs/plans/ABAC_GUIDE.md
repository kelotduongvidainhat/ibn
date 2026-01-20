# 🔐 ABAC Security Architecture

The IBN Platform uses **Attribute-Based Access Control (ABAC)** to enforce granular functional roles. Authorization decisions are made based on attributes embedded in the user's X.509 certificate (ecerts).

## 🎭 Roles & Permissions

| Role | Description | Permissions |
| :--- | :--- | :--- |
| **admin** | Superuser with full governance rights. | `InitLedger`, `CreateAsset`, `UpgradeChaincode` |
| **manager** | Executive user responsible for asset management. | `CreateAsset`, `ReadAsset` |
| **viewer** | Read-only auditor or stakeholder. | `ReadAsset`, `QueryAssets` |

## 🛠️ Implementation

### 1. Identity Provisioning
Identities are registered with attributes using the Fabric CA:
```bash
fabric-ca-client register --id.name manager1 --id.attrs 'role=manager:ecert'
```
The `:ecert` suffix ensures the attribute is included in the signing certificate.

### 2. Chaincode Guard
The smart contract extracts and verifies these attributes using the `cid` library:
```go
val, ok, err := ctx.GetClientIdentity().GetAttributeValue("role")
if val != "admin" && val != "manager" {
    return fmt.Errorf("access denied")
}
```

## 🧪 Verification
Execute the automated security test:
```bash
./network/scripts/test-abac.sh
```
This script attempts `CreateAsset` calls with different user roles to verify isolation boundary compliance.
