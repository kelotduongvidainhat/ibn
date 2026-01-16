# Item: Endorsement Policy (The Rules of Consensus)

An **Endorsement Policy** defines which organizations must sign (endorse) a transaction for it to be considered valid by the network.

## 1. Definition
In Hyperledger Fabric, endorsement happens *before* the transaction is committed to the ledger. Peers simulate the transaction and sign the results. The Orderer then checks if the collected signatures satisfy the policy defined for that chaincode.

## 2. Dynamic Policy Library
The IBN platform provides a library of pre-configured patterns that automatically adapt to your consortium's size. These are managed via `network/scripts/policy-gen.sh`.

| Pattern | Fabric Logic | Governance Strategy |
| :--- | :--- | :--- |
| **`MAJORITY`** | `OutOf(N/2+1, ...)` | **Democratic**: Requires >50% of the organizations to agree. Prevents a single organization from blocking the network. |
| **`ALL`** | `AND(Org1, Org2, ...)` | **Strict**: Requires every single member to sign. Used for critical operations like membership changes or asset destruction. |
| **`ANY`** | `OR(Org1, Org2, ...)` | **Open**: Any single organization can validate the transaction. Ideal for high-throughput public logs. |
| **`VETO`** | `AND(Org1, MAJORITY)` | **Founder-Led**: Requires the founding organization (Org1) PLUS a majority of the others. |
| **`ANY_2`** | `OutOf(2, ...)` | **Fault-Tolerant**: Requires any two signatures. Good for performance-heavy networks with many members. |

## 3. How to Apply a Policy
Policies are applied during the **Chaincode Lifecycle**. 

### A. Initial Deployment
When committing chaincode for the first time using `mass-commit.sh`, you can specify the policy:
```bash
./network/scripts/mass-commit.sh basic 1.0 1 mychannel "AND('Org1MSP.peer', 'Org2MSP.peer')"
```

### B. Atomic Upgrades (The Preferred Way)
The IBN platform allows you to switch governance models during an upgrade without manually writing complex strings:
```bash
./ibn-ctl upgrade basic mychannel ALL
```
This triggers `upgrade-cc.sh`, which calculates the current members and generates the `ALL` policy string automatically.

## 4. Auditing Policies
To verify which policy is currently active on a channel, use the **Governance Inspector**:
```bash
./ibn-ctl audit mychannel
```
The inspector decodes the on-chain binary configuration and displays the simplified rule (e.g., `Custom: OR(Org1MSP, Org2MSP, ...)`).

## 5. Why Use Custom Policies?
1. **Trust Modeling**: Not all data requires the same level of trust. "Coffee Inventory" might only need `ANY`, while "Land Title Transfer" needs `ALL`.
2. **Resilience**: A `MAJORITY` policy ensures the network stays alive even if some organizations' nodes are down for maintenance.
3. **Control**: The `VETO` pattern ensures that the platform anchor organization maintains oversight over specific high-risk application logic.
