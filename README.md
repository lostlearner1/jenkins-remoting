# Jenkins Remoting System

Enterprise-grade Jenkins Remoting Infrastructure with isolated execution nodes, multi-architecture build distribution, automated Configuration as Code (JCasC), and hardened container namespaces.

---

## 📑 Architecture Overview

```
                          ┌──────────────────────────┐
                          │    Jenkins Controller    │
                          │     (Zero Executors)     │
                          │      Dark Theme UI       │
                          │   Global Credentials     │
                          └─────────────┬────────────┘
                                        │
                    ┌───────────────────┴───────────────────┐
                    │                                       │
            (SSH Remoting: 22)                      (JNLP Remoting: 50000)
                    │                                       │
                    ▼                                       ▼
       ┌─────────────────────────┐             ┌─────────────────────────┐
       │   linux-ssh-agent-01    │             │  linux-inbound-agent-02 │
       │     (Debian/x86_64)     │             │     (Alpine Linux)      │
       │   Isolated Workspace    │             │   Isolated Workspace    │
       │    Labels: ssh, linux   │             │  Labels: inbound-agent  │
       └─────────────────────────┘             └─────────────────────────┘
```

### Key Security & Architectural Principles
1. **Zero-Executor Master (Controller Isolation)**:
   - The Jenkins Controller has `numExecutors: 0`. No user-submitted builds or untrusted scripts ever run on the controller host.
2. **Dedicated Worker Agents**:
   - **`linux-ssh-agent-01`**: Provisioned via SSH Remoting over private Docker bridge network (`jenkins-net`). Authenticated with non-interactive ED25519 SSH keys.
   - **`linux-inbound-agent-02`**: Provisioned via TCP Inbound (JNLP) protocol with automated secret negotiation.
3. **Configuration as Code (JCasC)**:
   - The entire cluster state—security realm, credentials, agent nodes, and sample pipeline jobs—is version-controlled and reproducible.
4. **Dark Mode UI**:
   - Integrated `dark-theme` and `theme-manager` plugins for a modern, Notion/IDE-style aesthetic.

---

## 🚀 Quick Start

### 1. Prerequisites
- **Docker Desktop** (running with Docker Compose v2+)
- **PowerShell** (Windows) or Bash

### 2. Start the Cluster
Run the startup script:
```powershell
.\scripts\start.ps1
```
This script will:
- Generate ED25519 SSH keypair in `secrets/` if not present.
- Build and launch the Jenkins Controller and both Agent containers.
- Wait until Jenkins Web UI is fully initialized.

### 3. Access Jenkins
- **URL**: [http://localhost:8080](http://localhost:8080)
- **Username**: `admin`
- **Password**: `admin123`

---

## 🧪 Automated Testing & Verification

Run the automated health check and verification script:
```powershell
.\scripts\test-remoting.ps1
```

### Pre-Configured Test Pipelines
1. **`01-linux-ssh-build`**:
   - Dispatched strictly to `linux-ssh-agent-01` using label `ssh`.
   - Validates user permissions, workspace directories, and environment isolation.
2. **`02-linux-inbound-build`**:
   - Dispatched strictly to `linux-inbound-agent-02` using label `inbound-agent`.
   - Validates TCP JNLP connectivity and workload generation.
3. **`03-distributed-multi-arch-matrix`**:
   - Dispatches parallel tasks simultaneously across both worker nodes.
   - Verifies concurrent load balancing and workspace segregation.

---

## 📂 Project Structure

```
.
├── docker-compose.yml              # Cluster definition (Controller + 2 Agents)
├── .env                            # Environment variables & admin credentials
├── controller/
│   ├── Dockerfile                  # Jenkins LTS with bundled plugins
│   ├── plugins.txt                 # JCasC, SSH, Pipeline, and Dark Theme plugins
│   └── casc/
│       ├── jenkins.yaml            # JCasC configuration (Nodes, Security, Credentials)
│       └── jobs.groovy             # Automated Job DSL pipeline definitions
├── agents/
│   ├── ssh-agent/
│   │   └── Dockerfile              # JDK21 SSH Agent
│   └── inbound-agent/
│       ├── Dockerfile              # Alpine JDK21 Inbound Agent
│       └── entrypoint.sh           # Auto-negotiating JNLP launcher
├── secrets/                        # Auto-generated SSH keys (gitignored)
└── scripts/
    ├── init-secrets.ps1            # Keypair generator
    ├── start.ps1                   # One-click start & health wait
    ├── stop.ps1                    # Clean shutdown
    └── test-remoting.ps1           # API test runner & node verification
```

---

## 🛑 Stopping the Infrastructure

To stop all containers:
```powershell
.\scripts\stop.ps1
```
To clean all data including volumes:
```powershell
docker compose down -v
```
