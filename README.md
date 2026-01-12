# Hyperledger Fabric MVP (CaaS & Fabric CA)

This project implements a high-performance, production-grade Hyperledger Fabric network designed for rapid development using **Chaincode-as-a-Service (CaaS)** and **Fabric Certificate Authorities (CA)**.

## ✨ Quick Access
👉 **[Read the 5-Minute QUICKSTART.md](./QUICKSTART.md)**

## ✅ Project Status
- [x] **Phase 1: Planning & Setup** (Multi-CA Architecture)
- [x] **Phase 2: Network Infrastructure** (Dynamic Enrollment, Healthy Nodes)
- [x] **Phase 3: Smart Contract (CaaS)** (Go Contract, Dockerized Service)
- [x] **Phase 4: Backend API** (Fabric Gateway, REST Endpoints)
- [x] **Phase 6: Fabric CA Integration** (Mutual TLS, Authority-based Enrollment)
- [🚧] **Phase 5: Advanced Logic** (History, Transfers, Automated Scripts)

## 🏗️ Project Structure

```text
.
├── bin/                 # Fabric v2.5 binaries
├── builders/            # External builder for CaaS
├── network/             # Network YAMLs, CA config, and automation scripts
│   ├── scripts/         # bootstrap-ca.sh, enroll-identities.sh, deploy-caas.sh
│   └── packaging/       # connection.json and .tar.gz packages
├── backend/             # Go Gateway API (Gin Framework)
├── chaincode/           # Smart contract source code (Go)
│   ├── cmd/             # CaaS server wrapper entry point
│   └── Dockerfile       # Container definition for the CC service
└── README.md            # Overall project status
```

## 🚀 Getting Started

### 1. Build & Start Network (Auto-CA)
Run the automated bootstrap script to launch CAs, enroll identities, and create the channel:
```bash
./network/scripts/bootstrap-ca.sh
```

### 2. Deploy Chaincode
Install, approve, and commit the chaincode definition:
```bash
./network/scripts/deploy-caas.sh
```

### 3. Launch Chaincode Service
Start the external chaincode container:
```bash
docker-compose -f network/docker-compose.yaml up -d chaincode-basic
```

### 4. Verify
```bash
# Manual query via CLI
docker exec cli peer chaincode query -C mychannel -n basic -c '{"Args":["ReadAsset","asset1"]}'
```

## 🛠 Features Enabled
- **Fabric CA Integration**: Dynamic identity management with dedicated CAs for Org1 and Orderer.
- **Node OUs**: Automated role identification (Admin vs Peer vs Client).
- **CaaS Workflow**: Chaincode runs as an external service for instant development cycles.
- **Mutual TLS**: Enforced across all boundaries with host-validated certificates.
- **Modern Channeling**: Uses `osnadmin` and Application Channel Participation.
