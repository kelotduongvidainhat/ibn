# 🚀 Hyperledger Fabric MVP Quickstart

Follow these steps to spin up the entire blockchain stack from scratch.

## 1️⃣ Infrastructure Setup
Bootstrap the network (Identities, Genesis, Channels):
```bash
./network/scripts/bootstrap.sh
```

## 2️⃣ Chaincode Deployment
Prepare the chaincode definition and approve/commit to the channel:
```bash
./network/scripts/deploy-caas.sh
```

## 3️⃣ Launch Services
Start the Chaincode Service and the Backend API:

### Start Chaincode (Docker)
```bash
docker-compose -f network/docker-compose.yaml up -d chaincode-basic
```

### Start Backend API (Local)
```bash
cd backend
go mod tidy
go run main.go
```

## 4️⃣ Verify & Test
Use `curl` to interact with the ledger via the API.

### Create an Asset
```bash
curl -X POST http://localhost:8080/api/assets \
  -H "Content-Type: application/json" \
  -d '{"ID":"asset99", "Color":"gold", "Size":50, "Owner":"Superuser", "AppraisedValue":1000}'
```

### Query an Asset
```bash
curl -X GET http://localhost:8080/api/assets/asset99
```

## 🔍 Useful Commands
- **Check Health**: `./network/scripts/test-network.sh`
- **View Logs**: `docker logs -f chaincode-basic`
- **Clean Everything**: `docker-compose -f network/docker-compose.yaml down --volumes`
