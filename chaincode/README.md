# Asset Management Chaincode (CaaS)

This smart contract implements a basic asset transfer ledger and is designed to run as a **Chaincode-as-a-Service (CaaS)** external to the Fabric Peer.

## 🏃 Running Locally (for Dev)

1. **Install Dependencies**
   ```bash
   go mod tidy
   ```

2. **Run as a Service**
   The binary requires configuration from the `.env` file:
   ```bash
   # Make sure .env is updated with the latest CHAINCODE_ID
   go run cmd/main.go
   ```

To deploy this as an external service:
1. **Package**: Run `tar` commands in `network/packaging` (automated by `deploy-caas.sh`).
2. **Install**: Install on Peer to get the `Package ID` (automated by `deploy-caas.sh`).
3. **Environment**: Update `chaincode/.env` with the new `CHAINCODE_ID`.
4. **Launch**: Build and start the container:
   ```bash
   docker-compose -f network/docker-compose.yaml up --build -d chaincode-basic
   ```

## 📝 Smart Contract API

| Function | Arguments | Description |
|---|---|---|
| `CreateAsset` | `id, color, size, owner, value` | Issues a new asset to the ledger. |
| `ReadAsset` | `id` | Retrieves an asset's properties. |
| `AssetExists` | `id` | Checks if an asset exists. |
