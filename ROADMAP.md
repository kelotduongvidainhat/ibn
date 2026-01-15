# 🗺️ Hyperledger Fabric Consortium Roadmap

This document outlines the strategic progression of the IBN (Integrated Blockchain Network) project. Our vision is to evolve this from a localized MVP into a **Multi-Channel Platform** capable of orchestrating numerous independent applications, each running on its own isolated channel with custom governance.

---

## ✅ Phase 1-6: Foundation & Infrastructure (Completed)
*   **Multi-Org Network Architecture**: 6-Org capable network with RAFT consensus.
*   **Fabric CA Integration**: Dynamic identity enrollment with NodeOUs (Admin/Peer/Client).
*   **Chaincode-as-a-Service (CaaS)**: Go-based contract running as an external service for rapid iteration.
*   **State Database Migration**: LevelDB to **CouchDB** for Rich JSON Query capability.
*   **Automated Admin Toolkit**: `ibn-ctl` and `add-org.sh` for one-button scaling.
*   **Backend Gateway**: REST API (Gin) with Fabric Gateway SDK integration.

---

## 🚀 Phase 7: Platform Orchestration & Scaling (Current)
*   **[x] Dynamic Orderer Scaling**: Automated expansion of the Raft consensus cluster with auto-incrementing IDs and quorum advisory.
*   **[ ] Multi-Channel Automation**: Create scripts to dynamically provision new application channels without manual "Admin Dances."
*   **[ ] Chaincode Multi-Tenancy**: Configure the backend to support concurrent connections to different chaincodes across various channels.
*   **[ ] Advanced Endorsement Patterns**: Implement a library of endorsement policy templates (e.g., Majority, AnyOne, All-Or-None) for different governance models.
*   **[ ] Private Data Collections (PDC)**: Establish standard patterns for managing sensitive data using side-databases that are decoupled from specific app logic.
*   **[ ] Inter-Channel Communication**: Research and implement logic for sharing specific state/assets between channels safely.

---

## 🖼️ Phase 8: Decentralized Storage (IPFS)
*   **[ ] IPFS Node Integration**: Deploy a sidecar IPFS node for the consortium.
*   **[ ] Off-Chain Storage**: Modify Smart Contract to store IPFS Content Identifiers (CIDs) instead of raw image data.
*   **[ ] Client-Side Resolution**: Backend API and Frontend integration for CID-to-Image rendering.
*   **[ ] Data Persistence**: Implement IPFS pinning strategies for critical asset artifacts.

---

## 🔐 Phase 9: Enterprise Security & Governance
*   **[ ] Policy-as-Code (OPA)**: Integrate Open Policy Agent for fine-grained authorization outside the ledger.
*   **[ ] Attribute-Based Access Control (ABAC)**: Use Fabric CA attributes (e.g., `role:manager`) to restrict smart contract functions.
*   **[ ] Certificate Revocation**: Implement/Test CRL (Certificate Revocation List) management.
*   **[ ] Mutual TLS Hardening**: External domain validation and cert-manager integration.

---

## 📊 Phase 10: Observability & DevSecOps
*   **[ ] Monitoring Dashboards**: Prometheus exporters for Fabric metrics + Grafana visualization.
*   **[ ] ELK Stack Integration**: Centralized logging for all 6 Organizations and Orderers.
*   **[ ] Block Visualizer**: Implement a lightweight block explorer to track transaction flow in real-time.
*   **[ ] CI/CD Pipelines**: Automated chaincode testing and deployment to the CaaS registry.

---

## 🌐 Phase 11: Production & Scaling (Mainnet Readiness)
*   **[ ] Kubernetes (K8s) Orchestration**: Transition Docker-compose to Helm Charts for multi-host deployment.
*   **[ ] Intermediate CAs**: Implement a multi-tier CA hierarchy for production-grade security.
*   **[ ] External Builders**: Secure the CaaS builder interface for enterprise environments.

---

## 📅 Timeline Estimates
| Milestone | Status | Target Date |
| :--- | :--- | :--- |
| Foundation & CouchDB | Completed | Jan 2026 |
| Platform Orchestration | In-Progress | Feb 2026 |
| IPFS & Storage | Backlog | Q1 2026 |
| Enterprise Governance | Backlog | Q2 2026 |
| Production K8s Migration | Backlog | Q3 2026 |
