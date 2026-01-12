# Hyperledger Fabric Troubleshooting Guide (Complete) (Updated: 2026-01-12) (Project: hyperledger-fabric-skeleton)

This guide consolidates all known issues, error messages, and solutions for deploying and managing the Hyperledger Fabric network, CaaS Chaincode, and Backend API.

## Table of Contents

1.  [Chaincode-as-a-Service (CaaS) Errors](#1-chaincode-as-a-service-caas-errors)
    *   [Chaincode Registration Failed (Timeout)](#11-chaincode-registration-failed-timeout-expired)
    *   [Chaincode Definition exists but not installed](#12-chaincode-definition-exists-but-not-installed)
    *   [Peer will not accept external connection](#13-peer-will-not-accept-external-chaincode-connection)
    *   [Packaging Issues inside Scripts](#14-packaging-issues-inside-scripts)
2.  [Backend & API Errors](#2-backend--api-errors)
    *   [Backend Access Denied](#21-backend-access-denied-channel-creator-org)
    *   [TLS Certificate Verification Failed](#22-tls-certificate-verification-failed)
    *   [Zombie Backend Process](#23-zombie-backend-process)
3.  [Network & Infrastructure Errors](#3-network--infrastructure-errors)
    *   [Endorsement Policy Failures](#31-endorsement-policy-failure)
    *   [Connection Refused / Network Issues](#32-connection-refused)
    *   [Version Compatibility](#33-version-compatibility--timeouts)
    *   [CA Configuration Mismatch](#34-ca-issues)
    *   [Gossip & Discovery (Anchor Peers)](#35-discovery-failures)

---

## 1. Chaincode-as-a-Service (CaaS) Errors

### 1.1 `Chaincode Registration Failed: Timeout Expired`

**Error Log:**
```
Error: endorsement failure during invoke. response: status:500 message:"error in simulation: ... could not launch chaincode basic_1.0:<hash>: chaincode registration failed: connection to basic_1.0:<hash> failed: ... context deadline exceeded"
```

**Cause:**
The Peer processes the transaction but fails to connect to the external chaincode container.
1.  **Mismatched IDs**: The `CHAINCODE_ID` in the chaincode container does not match the specific hash installed on the Peer.
2.  **Network Isolation**: The chaincode container is not on the correct Docker network (`fabric_test`).
3.  **Container Down**: The chaincode container is stopped.

**Solution:**
1.  **Get Package ID**: Run `peer lifecycle chaincode queryinstalled` (inside CLI).
2.  **Update `.env`**: Update `network/.env` with `CHAINCODE_ID=<PackageID>`.
3.  **Restart Container**: `docker-compose -f network/docker-compose.yaml up -d --no-deps chaincode-basic`.

### 1.2 `Chaincode Definition exists, but chaincode is not installed`

**Error Log:**
```
message:"make sure the chaincode basic has been successfully defined on channel mychannel and try again: chaincode definition for 'basic' exists, but chaincode is not installed"
```

**Cause:**
The ledger has a committed definition (e.g., Sequence 1) pointing to a Package ID, but the Peer's local storage does not contain that specific package. This happens if you reinstall the chaincode (generating a new hash) but forget to Approve/Commit the new definition (Sequence 2).

**Solution:**
1.  **Check Installed**: `peer lifecycle chaincode queryinstalled`.
2.  **Check Committed**: `peer lifecycle chaincode querycommitted --channelID mychannel --name basic`.
3.  **Sync**: Approve and Commit the new definition with an incremented sequence number.

### 1.3 `Peer will not accept external chaincode connection`

**Error Log:**
```
peer will not accept external chaincode connection (except in dev mode)
```

**Cause:**
Legacy error message often masking an incorrect `CHAINCODE_ID` format in the container environment. The ID **must** be the full Package ID (`<label>:<hash>`).

**Solution:**
Ensuring `CHAINCODE_ID` includes the hash:
`basic_1.0:72532aa0858d4c2d11fe7355936842ce76118efb89ad23f52200c9938d4e8d6f`

4.  **Missing External Builder**: Even with the correct ID, the peer must be configured to use an external builder for `ccaas` types. Ensure these are set in `docker-compose.yaml`:
    ```yaml
    - CORE_CHAINCODE_EXTERNALBUILDERS=[{"name":"ccaas-builder","path":"/opt/hyperledger/builders/ccaas","propagateEnvironment":["CORE_PEER_ID","CORE_PEER_LOCALMSPID"]}]
    ```
    And mount the builders:
    ```yaml
    volumes:
      - ../builders/ccaas:/opt/hyperledger/builders/ccaas
    ```

### 1.4 Packaging Issues inside Scripts

**Error:**
`tar: ...: No such file or directory` or `cp: ... No such file`.

**Cause:**
Deployment scripts running inside containers often have different working directories or lack access to host-generated files.

**Solution:**
*   **Package on Host**: Generate `basic.tar.gz` on the host machine.
*   **Copy to Container**: `docker cp basic.tar.gz cli:/opt/gopath/src/github.com/hyperledger/fabric/peer/`.
*   **Install from CLI**: Execute `peer lifecycle chaincode install basic.tar.gz`.

---

## 2. Backend & API Errors

### 2.1 `Backend Access Denied: channel creator org`

**Error Log:**
```
access denied: channel [mychannel] creator org [Org1MSP]
```

**Cause:**
Typically due to **NodeOU configuration mismatch** in the identity being used. If `config.yaml` enables NodeOUs, but the Orderer or Admin certs lack the `Orderer` or `Admin` OU, validation fails.

**Solution:**
Verify the user enrollment type:
```bash
fabric-ca-client enroll -u https://admin:adminpw@localhost:7054 --mspdir ...
```
Ensure `config.yaml` is present in the MSP directory.

### 2.2 TLS Certificate Verification Failed

**Error Log:**
```
x509: certificate signed by unknown authority
```

**Cause:**
1.  **Stale Volumes**: Old CA data persists after a network restart, causing certificate mismatch.
2.  **Zombie Process**: An old instance of the backend is still running with old certs loaded.

**Solution:**
1.  **Prune Volumes**: `docker volume prune -af` (Use `fresh-start.sh`).
2.  **Kill Backend**: `pkill backend` and restart.

### 2.3 Zombie Backend Process

**Symptoms:**
New changes to code or network don't seem to apply. API returns 404 for new endpoints.

**Solution:**
Check for rogue processes:
```bash
Ps aux | grep backend
fuser -k 3000/tcp
```

### 2.4 Private Key Parsing: `x509: failed to parse private key`

**Error Log:**
```
identity not found: failed to parse private key (use ParseECPrivateKey instead for this key format)
```

**Cause:**
Fabric CA often issues EC private keys in **SEC1** format (starts with `-----BEGIN EC PRIVATE KEY-----`). The standard `x509.ParsePKCS8PrivateKey` used in some SDK versions may not support this directly.

**Solution:**
Update `wallet.go` to use a fallback parser:
```go
block, _ := pem.Decode(privateKeyPEM)
if block != nil && block.Type == "EC PRIVATE KEY" {
    privateKey, err = x509.ParseECPrivateKey(block.Bytes)
}
```

### 2.5 Identity Mismatch: `creator is malformed` / `org unknown`

**Error Log:**
```
error validating proposal: access denied: channel [mychannel] creator org unknown, creator is malformed
```

**Cause:**
The Fabric CA re-initialized with a default self-signed root certificate, but the channel was bootstrapped using a different root cert from `crypto-config`. The user's certificate is valid for the CA, but the Peer/Channel doesn't trust that CA.

**Solution:**
Explicitly point the CA to the correct root certificates in `docker-compose.yaml`:
```yaml
environment:
  - FABRIC_CA_SERVER_CA_CERTFILE=/etc/hyperledger/fabric-ca-server-config/ca.org1.example.com-cert.pem
  - FABRIC_CA_SERVER_CA_KEYFILE=/etc/hyperledger/fabric-ca-server-config/priv_sk
```

---

## 3. Network & Infrastructure Errors

### 3.1 `ENDORSEMENT_POLICY_FAILURE`

**Error Log:**
```
implicit policy evaluation failed - 1 sub-policies were satisfied, but this policy requires 2
```

**Cause:**
Default endorsement policy requires **Majority** (or All) members to endorse. If you only send the transaction to Org1's peer, it fails validation.

**Solution:**
Always target **BOTH** peers in `invoke` commands:
```bash
peer chaincode invoke ... \
  --peerAddresses peer0.org1.example.com:7051 ... \
  --peerAddresses peer0.org2.example.com:9051 ...
```

### 3.2 Connection Refused

**Solution:**
Check Docker containers status.
`docker ps`
Restart the specific node: `docker-compose restart peer0.org1.example.com`.

### 3.3 Version Compatibility & Timeouts

**Cause:**
Using `fabric-samples` binaries (v2.5) with v1.4 configuration or vice versa.

**Solution:**
Ensure `FABRIC_CFG_PATH` points to the correct version's config. Use `peer version` to verify alignment.

### 3.4 CA Issues

**Error:** `Configuration file version mismatch`
**Solution:** Ensure `fabric-ca-server-config.yaml` version matches the Docker image version (`1.5.x`).

### 3.5 Discovery Failures: `no combination of peers satisfy endorsement policy`

**Error Log (Backend/Gateway):**
```
failed to endorse transaction: no combination of peers can be derived which satisfy the endorsement policy
```

**Cause:**
Service Discovery is enabled, but the Org1 peer cannot "see" the Org2 peer across the network. This happens if **Anchor Peers** are not configured in the channel. Discovery only returns Org1 peers, which is insufficient for a "Majority" policy.

**Solution:**
Update Anchor Peers for both organizations:
1.  Fetch channel config.
2.  Add Anchor Peer addresses (`peer0.org1.example.com:7051`, etc.).
3.  Submit config update.
   *(Use `scripts/update-anchor-peers.sh`)*

---

### 2.6 Registration Errors (TLS & Duplicate Users)

**Error Log (TLS Enabled):**
```
failed to call CA: Post "https://localhost:7054/api/v1/enroll": x509: certificate signed by unknown authority
```
**Cause:**
The Backend is trying to connect to a TLS-enabled CA but the CA's self-signed certificate is not trusted by the host's CA store.

**Solution:**
In development, use `InsecureSkipVerify: true` in the backend's `http.Client`. In production, load the CA's root certificate into the `CertPool`.

**Error Log (Duplicate User):**
```
Error: registration failed: Identity 'user1' is already registered
```
**Cause:**
Attempting to register a username that already exists in the CA database.

**Solution:**
Implement a check in the backend (`RegisterUser`) to catch the specific string `"is already registered"` in the command output and return a successful status (201/200) to the user, as the identity is usable.

---

**Error Log (Email Duplicate):**
```
duplicate key value violates unique constraint "idx_users_email"
```
**Cause:**
Multiple users registered without an email address, causing empty string `""` collisions in the database's unique `email` column.

**Solution:**
Ensure unique emails are provided or generated. The backend now generates `<username>@example.org` if no email is provided to prevent DB registration failure.

---

### 2.8 Database Reset: `ERROR: replication slot "..." already exists`
**Solution:**
If you see replication errors after a crash, remove the local postgres data volume:
`docker volume rm network_postgres_data` (or similar) followed by `sudo ./scripts/fresh-start.sh`.

---

## 4. Containerization Pitfalls

### 4.1 TimeZone Missing: `unknown time zone Asia/Ho_Chi_Minh`
**Cause:**
Alpine Linux (commonly used in light Docker images) does not include timezone data by default.
**Solution:**
Ensure `tzdata` is installed in the final Docker image stage:
`RUN apk add --no-cache tzdata`

### 4.2 Module Version Mismatch: `go.mod requires go >= 1.25.2`
**Cause:**
Building a project with a `go.mod` specifying a version higher than the Go installed in the Docker image.
**Solution:**
Use the `golang:alpine` or `golang:1.25-alpine` base image in the build stage.

### 4.3 Node.js / Vite Incompatibility: `crypto.hash is not a function`
**Cause:**
The latest versions of Vite require Node.js 20+ or 22+. Node 18 lacks certain crypto APIs used by the bundler.
**Solution:**
Upgrade the frontend Docker image to `node:22-alpine`.

### 4.4 Internal Networking: Backend cannot find Postgres/Peer
**Cause:**
Hardcoded `localhost` inside a container refers to the container itself, not the host or other services.
**Solution:**
1.  Use service names from `docker-compose.yaml` (e.g., `DB_HOST=postgres`).
2.  Ensure all services are on the same Docker network (e.g., `fabric_test`).

---

**Last Updated**: 2026-01-08

### 2.7 Identity Collision: `Authentication failure` on Multi-Org

**Symptoms:**
Admin from Org2 cannot log in, or logs show `Authentication failure` for one org while working for another.

**Cause:**
Shared wallet directory (`./wallet/admin`) caused Org identities with the same name to overwrite each other.

**Solution:**
The wallet structure has been updated to include the MSPID: `./wallet/<MSPID>/<username>/`. This ensures that even if both Orgs have an `admin`, their certificates are stored separately.
