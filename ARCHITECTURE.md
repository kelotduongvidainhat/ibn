# 🏛️ Consortium Platform Architecture

This document defines the **Multi-Application Backbone** for the IBN (Integrated Blockchain Network). The goal of this architecture is to decouple **Platform Infrastructure** from **Application Logic**, allowing a single consortium to manage numerous independent blockchain applications (channels) with minimal friction.

## 🏗️ The 5 Pillars of Platform Independence

To scale to multiple applications (Tea-Tracking, Ownership, etc.), the following components must remain **Application-Agnostic**.

### 1. Unified Identity & Authority (IAM)
*   **The Component**: Fabric Certificate Authorities (CAs).
*   **Decoupling**: Identities are issued to **Organizations** and **Nodes**, not to specific applications.
*   **Platform Role**: Provides the cryptographic "passport" required to enter any channel. 
*   **Strategic Goal**: A user enrolled in Org1 should be able to authenticate across any channel they are permitted to join without re-enrolling.

### 2. Standardized Channel Orchestration
*   **The Component**: Channel Configuration Management (`configtxgen`, `osnadmin`).
*   **Decoupling**: The process of "The Admin Dance" (Fetching config -> Injecting Org -> Signing -> Updating) is identical regardless of the channel's purpose.
*   **Platform Role**: Provides the "Plumbing" to create isolated logical networks (`channel-tea`, `channel-docs`, etc.) on demand.
*   **Strategic Goal**: Automation that allows a non-technical tenant to "Purchase a Channel" via API.

### 3. Connection Discovery (Gateway Logic)
*   **The Component**: Connection Profiles (JSON) and Gateway SDK.
*   **Decoupling**: The backend connects to **Peers**, not just to a specific smart contract.
*   **Platform Role**: Provides a "Unified Entry Point" for all applications.
*   **Strategic Goal**: The Backend API acts as a transparent proxy. It receives a `ChannelName` and `ContractName` and routes the request to the correct physical nodes.

### 4. Governance Policy Templates
*   **The Component**: Endorsement Policies (`signature-policy`).
*   **Decoupling**: Reusable rule-sets like `OR('Org1.peer', 'Org2.peer')` or `AND(ALL-ORGS)`.
*   **Platform Role**: Provides a "Menu of Trust" for new applications.
*   **Strategic Goal**: New applications "Subscribe" to a policy template instead of writing complex JSON rules from scratch.

### 5. Universal Observability
*   **The Component**: Health Checks & Resource Monitors.
*   **Decoupling**: Monitoring Docker metrics (CPU/RAM) and Ledger Sync (Block Height).
*   **Platform Role**: Ensures the "Engine" is running smoothly, regardless of what the "Cargo" (Data) is.
*   **Strategic Goal**: Real-time alerts if a node lags behind, preventing platform-wide degradation.

---

## 🗺️ Conceptual Layers

```text
┌─────────────────────────────────────────────────────────────┐
│                   CLIENT APPLICATIONS                       │
│      (Tea-Tracking UI)   (Owner-Registry UI)   (...)        │
└──────────────┬──────────────────┬───────────────────────────┘
               ▼                  ▼
┌─────────────────────────────────────────────────────────────┐
│                   PLATFORM GATEWAY (Backend)                │
│       - Auth Verification    - Connection Discovery         │
│       - Multi-Channel Router - Policy Enforcement          │
└──────────────┬──────────────────┬───────────────────────────┘
               ▼                  ▼
┌─────────────────────────────────────────────────────────────┐
│                  CONSORTIUM INFRASTRUCTURE                  │
│   ┌──────────────┐   ┌──────────────┐   ┌──────────────┐    │
│   │  Channel: A  │   │  Channel: B  │   │  Channel: C  │    │
│   │ (Tea Supply) │   │ (Legal Reg)  │   │ (Insurance)  │    │
│   └──────────────┘   └──────────────┘   └──────────────┘    │
│                                                             │
│   ┌──────────────────────────────────────────────────────┐  │
│   │             SHARED FABRIC NODES (Peers)              │  │
│   │      (Managed by Org1, Org2, Org3, etc.)             │  │
│   └──────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

## 🛠️ Implementation Checklist (Platform vs. App)

| Feature | Category | Rationale |
| :--- | :--- | :--- |
| **`Fresh-Start.sh`** | **Platform** | Sets up the hardware/nodes. |
| **`Add-Org.sh`** | **Platform** | Expands the consortium membership. |
| **`SmartContract.go`** | **Application** | Defines the specific data (e.g., Tea Grade). |
| **`CouchDB`** | **Platform** | Required by peers regardless of data type. |
| **`TLS Certs`** | **Platform** | Independent of the transaction contents. |
| **`Rich Query API`** | **Platform** | Generic interface to access the database. |

---

## 📈 Success Metric
The platform is successful when a new, completely different application (e.g., *Healthcare Records*) can be deployed to a new channel using **zero** changes to the existing `network/scripts/` and `backend/internal/fabric/` modules.
