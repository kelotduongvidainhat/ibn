# Hyperledger Fabric MVP (CaaS Optimized)

This project implements a high-performance, minimal Hyperledger Fabric network designed for rapid development using **Chaincode-as-a-Service (CaaS)**.

## ✨ Quick Access
👉 **[Read the 5-Minute QUICKSTART.md](./QUICKSTART.md)**

## ✅ Project Status
- [x] **Phase 1: Planning & Setup** (Cryptogen Bootstrap)
- [x] **Phase 2: Network Infrastructure** (Genesis, Channel Join, Healthy Nodes)
- [x] **Phase 3: Smart Contract (CaaS)** (Go Contract, Dockerized Service, Verified transactions)
- [x] **Phase 4: Backend API** (Fabric Gateway, REST Endpoints, Curl verified)
- [🚧] **Phase 5: Advanced Logic** (History, Transfers, Automated Scripts)

## 🏗️ Project Structure

```text
.
├── bin/                 # Fabric v2.5 binaries
├── builders/            # External builder for CaaS
├── network/             # Network YAMLs, crypto, and automation scripts
│   ├── scripts/         # bootstrap.sh, test-network.sh, deploy-caas.sh
│   └── packaging/       # connection.json and .tar.gz packages
├── chaincode/           # Smart contract source code (Go)
│   ├── cmd/             # CaaS server wrapper entry point
│   └── Dockerfile       # Container definition for the CC service
└── README.md            # Overall project status
```

## 🚀 Getting Started

### 1. Build & Start Network
Run the automated bootstrap script to generate certificates, create the channel, and join nodes:
```bash
./network/scripts/bootstrap.sh
```

### 2. Deploy Chaincode
Install, approve, and commit the chaincode definition to the channel:
```bash
./network/scripts/deploy-caas.sh
```

### 3. Launch Chaincode Service
Start the external chaincode container (it will connect to the Peer automatically):
```bash
# This uses the PACKAGE_ID from chaincode/.env
docker-compose -f network/docker-compose.yaml up -d chaincode-basic
```

### 4. Verify
Run the health check or perform a test invoke:
```bash
./network/scripts/test-network.sh
# Or manual invoke
docker exec cli peer chaincode query -C mychannel -n basic -c '{"Args":["ReadAsset","asset1"]}'
```

## 🛠 Features Enabled
- **CaaS Workflow**: Chaincode runs as an external service, allowing for instant restarts.
- **Fast Bootstrap**: Uses `cryptogen` for static identity generation.
- **Modern Channeling**: Uses `osnadmin` and Application Channel Participation (No system channel).
- **Mutual TLS**: Enforced across all boundaries for maximum security.
