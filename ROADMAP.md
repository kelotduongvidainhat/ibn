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

## 🚀 Phase 7: Multi-Application Deployment (Current)
*   **[ ] Application 1: Tea-Tracking**: Deploy a supply-chain focused channel with provenance logic (harvest origin, batch IDs, quality certificates).
*   **[ ] Application 2: Owner-Registry**: Deploy a registry focused channel for legal titles and property ownership history.
*   **[ ] Private Data Collections (PDC)**: Implement "Side DBs" for sensitive application data (e.g., owner contact info) visible only to designated Orgs.
*   **[ ] Custom Channel Governance**: Define unique endorsement policies for each application (e.g., Tea-Tracking requires 1/N, whereas Ownership Registry requires 2/N).

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

## 🏗️ Phase 10: Multi-Channel Orchestration (Vision)
*   **[ ] Dynamic Channel Creation**: API-driven automation to spin up new channels for new applications/tenants.
*   **[ ] Application Isolation**: Support multiple different Chaincodes (Smart Contracts) running concurrently on dedicated channels.
*   **[ ] Inter-Channel Communication**: Implement logic for sharing specific state/assets between channels safely.
*   **[ ] Unified Identity**: Single CA hierarchy serving multiple applications across different logical boundaries.

---

## 📊 Phase 11: Observability & DevSecOps
*   **[ ] Monitoring Dashboards**: Prometheus exporters for Fabric metrics + Grafana visualization.
*   **[ ] ELK Stack Integration**: Centralized logging for all 6 Organizations and Orderers.
*   **[ ] Block Visualizer**: Implement a lightweight block explorer to track transaction flow in real-time.
*   **[ ] CI/CD Pipelines**: Automated chaincode testing and deployment to the CaaS registry.

---

## 🌐 Phase 12: Production & Scaling (Mainnet Readiness)
*   **[ ] Kubernetes (K8s) Orchestration**: Transition Docker-compose to Helm Charts for multi-host deployment.
*   **[ ] Intermediate CAs**: Implement a multi-tier CA hierarchy for production-grade security.
*   **[ ] External Builders**: Secure the CaaS builder interface for enterprise environments.

---

## 📅 Timeline Estimates
| Milestone | Status | Target Date |
| :--- | :--- | :--- |
| Foundation & CouchDB | Completed | Jan 2026 |
| Marketplace & Business Logic | In-Progress | Feb 2026 |
| IPFS & Multi-Channel Vision | Backlog | Q1 2026 |
| Enterprise Governance | Backlog | Q2 2026 |
| Production K8s Migration | Backlog | Q3 2026 |
