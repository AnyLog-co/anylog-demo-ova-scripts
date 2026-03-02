# 🚀 EdgeLake / AnyLog Demo OVA

[![Platform](https://img.shields.io/badge/platform-Docker-blue)]()
[![License](https://img.shields.io/badge/license-Demo-lightgrey)]()
[![Environment](https://img.shields.io/badge/environment-OVA-green)]()
[![Status](https://img.shields.io/badge/status-Demo-orange)]()

> A fully containerized distributed data fabric demo environment powered by **EdgeLake / AnyLog**.

---

# 📑 Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Components](#components)
- [Installation](#installation)
- [Startup](#startup)
- [Service Endpoints](#service-endpoints)
- [Data Flow](#data-flow)
- [Default Dataset](#default-dataset)
- [Security](#security)
- [Troubleshooting](#troubleshooting)
- [Tech Stack](#tech-stack)

---

# 📌 Overview

The EdgeLake Demo OVA provides a pre-configured distributed data fabric including:

- GUI Management Interface  
- Query Node (SQL Federation)  
- Master Node (Control Plane)  
- Two Operator Nodes (Data Ingest & Storage)  
- Grafana Monitoring Dashboard  

Designed for:

- Demonstrations  
- Training  
- Evaluation of distributed query fabric  
- Proof-of-concept deployments  

---

# 🏗 Architecture

```
                     ┌─────────────────────────┐
                     │        GUI (3001)       │
                     │   Web Management UI     │
                     └────────────┬────────────┘
                                  │ REST
        ┌─────────────────────────┴─────────────────────────┐
        │                                                   │
┌───────────────┐                               ┌────────────────┐
│   Query Node  │                               │  Master Node   │
│ (Port 32349)  │                               │  Control Plane │
└───────┬───────┘                               └────────────────┘
        │
        │ Distributed SQL
        │
 ┌──────┴───────────────┐
 │                      │
┌──────────────┐  ┌──────────────┐
│ Operator 1   │  │ Operator 2   │
│ (32149)      │  │ (32159)      │
└──────────────┘  └──────────────┘
```

---

# 🧩 Components

## GUI (`gui-1`)
- Web-based management interface
- Monitoring and health status
- SQL query builder
- Data ingestion management
- Blockchain metadata viewer

URL:  
`http://localhost:3001`

---

## Grafana
- Sample dashboard
- System metrics visualization

URL:  
`http://localhost:3000`

---

## Master Node
- Cluster coordination
- Node discovery & registration
- Metadata orchestration

---

## Query Node
- Executes distributed SQL queries
- REST-based query endpoint
- Aggregates operator results

Port:  
`VM_IP:32349`

---

## Operator Nodes (x2)
- Data ingestion endpoints
- Storage layer
- MQTT subscription support
- REST ingestion API

Ports:
- `VM_IP:32149`
- `VM_IP:32159`

---

# ⚙ Installation

## 1️⃣ Make Scripts Executable

```bash
chmod +x ALinstall.sh
chmod +x ALstartup.sh
chmod +x startup.sh
```

## 2️⃣ Configure Environment (Optional)

Edit:

```
ALinstall.env
```

## 3️⃣ Run Installation

```bash
./ALinstall.sh
```

This will:

- Prepare Docker runtime
- Configure containers
- Initialize environment

---

# ▶ Startup

## Automatic

Containers auto-start on OVA boot.

## Manual

```bash
cd ~/Edgelake
./ALstartup.sh
```

Verify running services:

```bash
docker ps
```

---

# 🌐 Service Endpoints

| Service | URL / Port |
|----------|------------|
| GUI | http://localhost:3001 |
| Grafana | http://localhost:3000 |
| Query Node | VM_IP:32349 |
| Operator 1 | VM_IP:32149 |
| Operator 2 | VM_IP:32159 |

---

# 🔄 Data Flow

## Ingestion Flow

1. Data enters an Operator node  
2. Data is validated & stored  
3. Metadata written to blockchain layer  
4. Query node becomes aware of new data  

## Query Flow

1. User submits SQL via GUI  
2. GUI forwards to Query node  
3. Query node distributes execution  
4. Operators return results  
5. Query node aggregates & returns response  

---

# 📦 Default Dataset

Database: `new_company`  
Table: `rand_data`  

Preloaded via MQTT feed on first launch.

---

# 🔐 Security

Default credentials:

```
Username: edgelake
Password: edgelake
```

⚠ Change immediately for non-demo or networked deployments.

All services are intended for local demo usage.

---

# 🛠 Troubleshooting

Check running containers:

```bash
docker ps
```

Restart services:

```bash
./ALstartup.sh
```

Reinstall:

```bash
./ALinstall.sh
```

View logs:

```bash
docker logs <container_name>
```

---

# 🧰 Tech Stack

- Docker
- EdgeLake Data Fabric
- AnyLog Distributed Engine
- REST APIs
- MQTT Ingestion
- SQL Federation
- Grafana
- Web GUI

---

# 📣 Summary

The EdgeLake Demo OVA delivers a multi-node distributed data fabric in a single deployable image.

It demonstrates:

- Distributed ingestion  
- Federated SQL queries  
- Blockchain-backed metadata  
- Multi-node orchestration  
- GUI-driven management  

---

⭐ Designed for technical demos, workshops, and proof-of-concept environments.
