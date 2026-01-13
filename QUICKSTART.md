# 🚀 Hyperledger Fabric MVP Quickstart

Follow these steps to spin up the entire production-style blockchain stack from scratch.

## 1️⃣ Infrastructure Setup
Bootstrap the network using Fabric Certificate Authorities:
```bash
# This stops old containers, cleans data, starts CAs, and enrolls identities
./network/scripts/bootstrap-ca.sh
```

## 2️⃣ Chaincode Deployment
Prepare the chaincode definition and commit it to the channel:
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

### 💎 Rich Query (New!)
Search for all assets with a specific color:
```bash
curl -G "http://localhost:8080/api/assets/query" \
  --data-urlencode 'query={"selector":{"Color":"gold"}}' | jq .
```

## 🔍 Path to Troubleshooting
- **Logs**: `docker logs -f peer0.org1.example.com` or `docker logs -f chaincode-basic`.
- **Clean Start**: `./network/scripts/bootstrap-ca.sh` handles cleaning for you.
- **Permissions**: If you see `permission denied`, the script will automatically attempt to use `sudo chown` to fix Docker-owned files.
