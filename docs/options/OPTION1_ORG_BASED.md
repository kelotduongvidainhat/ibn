# Option 1: Org-based Splitting (Horizontal)

## 📖 Concept
In this strategy, the network is divided by **Owner**. Each file contains the complete stack required for a single organization.

### Example File Structure
```text
network/compose/
  ├── docker-compose-base.yaml (Orderer, CLI, Backend)
  ├── docker-compose-orderers.yaml (Expansion Orderers)
  ├── docker-compose-org1.yaml (CA, Peer0, CouchDB0)
  ├── docker-compose-org2.yaml (CA, Peer0, CouchDB0)
  └── docker-compose-org3.yaml (CA, Peer0, CouchDB0)
```

## ✅ Pros
1. **Dynamic Scaling**: Adding a new organization is as simple as generating a new `orgN.yaml` file from a template.
2. **Blast Radius Isolation**: A syntax error in one organization's file cannot prevent other organizations from starting.
3. **Surgical Lifecycle**: To remove a member, you simply delete their `.yaml` file. No complex text-processing of a shared file is required.
4. **Independent Maintenance**: Org1 can upgrade their CouchDB version without forcing Org2 to do the same.

## ❌ Cons
1. **Code Duplication**: The same CA and Peer service definitions are repeated across files (though this can be solved with templates).
2. **Path Complexity**: Relative paths (like for volumes) must be carefully managed relative to the `compose/` directory.

## 🛠️ Usage in IBN
This is the default strategy for the IBN Superadmin Toolkit. It treats the network as a "Consortium of independent modules," which mirrors the real-world decentralization of Hyperledger Fabric.
