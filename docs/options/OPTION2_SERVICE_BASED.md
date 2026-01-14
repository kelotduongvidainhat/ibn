# Option 2: Service-based Splitting (Vertical)

## 📖 Concept
Infrastructure is divided by **Container Role**. All services of a certain type are grouped together regardless of which organization owns them.

### Example File Structure
```text
network/compose/
  ├── docker-compose-cas.yaml      (All Org CAs)
  ├── docker-compose-peers.yaml    (All Org Peers)
  ├── docker-compose-ledgers.yaml  (All CouchDB instances)
  └── docker-compose-orderers.yaml (Orderer Cluster)
```

## ✅ Pros
1. **Vertical Management**: Excellent for performing migrations on one specific layer (e.g., swapping LevelDB for CouchDB across the whole network).
2. **Resource Optimization**: Allows DevOps to easily apply `deploy` constraints (CPU/RAM limits) to all peers in one place.
3. **Connectivity Visualization**: Easier to see all peer-to-peer port mappings in a single file.

## ❌ Cons
1. **High Coupling**: Scaling an organization requires modifying **multiple files** (the CA file, the Peer file, and the Ledger file).
2. **Fragmented Governance**: It is difficult to answer the question "What infrastructure does Org 4 own?" because their containers are spread across multiple files.
3. **Atomic Failure Risk**: An error in `peers.yaml` while adding Org 10 could prevent Orgs 1 through 9 from starting.

## 🛠️ Usage in IBN
Used primarily in the `lab/service-split` branch for educational purposes to demonstrate how to isolate persistence layers for advanced monitoring.
