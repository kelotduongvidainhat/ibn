# Option 3: Inheritance & Layering

## 📖 Concept
This strategy utilizes the Docker Compose `extends` feature (or external pre-processors like Kustomize/Helm-style templating) to define a **Base Peer** and then create specific instances that inherit from it.

### Example File Structure
```yaml
# template-peer.yaml
services:
  base-peer:
    image: hyperledger/fabric-peer:2.5
    environment:
      - CORE_VM_ENDPOINT=unix:///host/var/run/docker.sock
      - FABRIC_LOGGING_SPEC=INFO

# docker-compose.yaml
services:
  peer0.org1.example.com:
    extends:
      file: template-peer.yaml
      service: base-peer
    environment:
      - CORE_PEER_LOCALMSPID=Org1MSP
```

## ✅ Pros
1. **DRY (Don't Repeat Yourself)**: Minimizes configuration noise. Changing a common environment variable once updates every peer.
2. **Configuration Enforcement**: Ensures that all peers in a cluster follow the exact same security and logging standards.
3. **Advanced Scalability**: Best for environments with hundreds of peers with identical baseline configurations.

## ❌ Cons
1. **Implicit Complexity**: The final state of a container is not visible in a single file. You must mentally merge the template and the specific file.
2. **Brittle Dependencies**: If the base template file is deleted or moved, all child services break immediately.
3. **Debugging Difficulty**: Tooling like `docker compose logs` or `top` still works, but mapping an error back to the exact YAML line is harder when inheritance is involved.

## 🛠️ Usage in IBN
Used in the `lab/inheritance` branch to explore high-density peer deployments and reducing the template size used in the `add-org.sh` script.
