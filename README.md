# 🚀 AnyLog / AnyLog Demo OVA

[![Platform](https://img.shields.io/badge/platform-Docker-blue)]()
[![License](https://img.shields.io/badge/license-Demo-lightgrey)]()
[![Environment](https://img.shields.io/badge/environment-OVA-green)]()
[![Status](https://img.shields.io/badge/status-Demo-orange)]()

> A fully containerized distributed data fabric demo environment powered by **AnyLog / AnyLog**.

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

The AnyLog Demo OVA provides a pre-configured distributed data fabric including:

- GUI Management Interface  
- Standalone Node (Control Plane, SQL Federation and Data Ingest and Storage)  
- Operator Node (Data Ingest & Storage)  
- Grafana Monitoring Dashboard  

Designed for:

- Demonstrations  
- Training  
- Evaluation of distributed query fabric  
- Proof-of-concept deployments  

---

# 🏗 Architecture

```
                          ┌───────────────────────────┐
                          │        GUI (31800)        │
                          │     Web Management UI     │
                          └─────────────┬─────────────┘
                                        │ REST
               ┌────────────────────────┴────────────────────────┐
               │                                                 │
  ┌────────────────────────┐               ┌─────────────────────────────────────┐
  │      Operator Node     │               │          Standalone Node            │
  │       Port 32159       │               │  Control Plane, Query and Operator  │
  └────────────────────────┘               └─────────────────────────────────────┘
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
`http://localhost:31800`

---

## Grafana
- Sample dashboard
- System metrics visualization

URL:  
`http://localhost:3000`

---

## Standalone Node
- Cluster coordination
- Node discovery & registration
- Metadata orchestration
- Executes distributed SQL queries
- REST-based query endpoint
- Aggregates operator results

Port:  
`VM_IP:32149`

---

## Operator Node
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
chmod +x startup.sh
```

## 2️⃣ Configure Environment (Optional)

Edit `ALinstall.env` before running the installer. Key variables:

| Variable | Default | Description |
|----------|---------|-------------|
| `LICENSE_KEY` | *(blank)* | Required. Prompted interactively if blank. Get one at https://www.anylog.network/download |
| `COMPANY_NAME` | `Anylog-Demo` | Company/organization name stamped on nodes |
| `NODE_TYPE` | `master` | Default node type hint (overridden by `-n` flag) |
| `COMPOSE_VER` | `pre-develop` | Branch of the docker-compose repo to clone |
| `TAG` | `1.4.2512-beta24` | AnyLog Docker image tag |
| `LEDGER_CONN` | `127.0.0.1:32148` | Master node TCP address for blockchain ledger |
| `REST_BIND` | `false` | Bind REST port to all interfaces |
| `TCP_BIND` | `true` | Bind TCP port to all interfaces |
| `BROKER_BIND` | `false` | Bind MQTT broker port to all interfaces |
| `ENABLE_MQTT` | `true` | Enable MQTT data ingestion |
| `MQTT_BROKER` | `172.104.228.251` | External MQTT broker address |
| `MSG_DBMS` | `new_company` | Database for MQTT-ingested data |
| `DEFAULT_DBMS` | `new_company` | Default database name |
| `NODE_MONITORING` | `true` | Enable node health monitoring |
| `STORE_MONITORING` | `true` | Persist monitoring data |
| `SYSLOG_MONITORING` | `true` | Enable syslog collection |
| `DOCKER_MONITORING` | `true` | Enable Docker stats monitoring |

## 3️⃣ Run Installation

```bash
./ALinstall.sh [OPTIONS] <command>
```

### Usage

```
ALinstall.sh [-e env_file] [-n node1,node2,...] [-s] [-k] [-d] install|uninstall|update|start|stop
```

### Commands

| Command | Description |
|---------|-------------|
| `install` | Clone docker-compose repo, configure node(s), and optionally start them |
| `uninstall` | Stop and remove running node containers and images |
| `update` | Uninstall running nodes, then reinstall with current config |
| `start` | Start configured node(s) via `make up` |
| `stop` | Stop running node(s) via `make down` |

### Flags

| Flag | Argument | Description |
|------|----------|-------------|
| `-e` | `<path>` | Path to environment file. Default: `./ALinstall.env` |
| `-n` | `<node1,node2,...>` | Comma-delimited list of node types to act on. Default: all valid nodes |
| `-s` | *(none)* | Auto-start nodes immediately after `install` or `update` |
| `-k` | *(none)* | Auto-stop running nodes before `uninstall` or `update` |
| `-d` | *(none)* | Demo mode: install/manage the full demo environment. Overrides `-n` |

### Valid Node Types

| Node Type | Description |
|-----------|-------------|
| `anylog-master` | Control plane / blockchain ledger node |
| `anylog-operator` | Data ingest and storage node |
| `anylog-query` | Federated SQL query node |
| `anylog-publisher` | Data publisher node |
| `anylog-generic` | Generic/custom AnyLog node |
| `anylog-standalone-operator` | Standalone operator (combined master + operator) |
| `anylog-standalone-publisher` | Standalone publisher (combined master + publisher) |

### Demo Mode (`-d`)

Demo mode installs the full preconfigured environment:

- `anylog-standalone-operator` — combined master + operator node
- `anylog-operator` — second operator node  
- `gui-1` — AnyLog web management UI (`port 31800`)
- `grafana` — preconfigured Grafana dashboard (`port 3000`)
- rsyslog forwarding to the operator broker port (`32160`)
- Desktop autostart entry for the startup README

### Examples

```bash
# Install full demo environment and start immediately
./ALinstall.sh -d -s install

# Install only master and query nodes
./ALinstall.sh -n anylog-master,anylog-query install

# Install with a custom env file and auto-start
./ALinstall.sh -e /opt/myconfig.env -s install

# Stop and uninstall only the operator node
./ALinstall.sh -n anylog-operator uninstall

# Update all nodes (auto-stop before, auto-start after)
./ALinstall.sh -k -s update

# Start previously installed nodes
./ALinstall.sh start

# Stop all running AnyLog nodes
./ALinstall.sh stop
```

### Logging

All install operations are logged to:

```
./logs/ALinstall_<command>_<YYYYMMDD_HHMMSS>.log
```

Logs capture both stdout and stderr and are written in addition to terminal output.

---

# ▶ Startup

## Automatic

Containers auto-start on OVA boot.

## Manual

```bash
cd ~/AnyLog
./ALinstallsh -s -n node1,node2
```

Verify running services:

```bash
docker ps
```

---

# 🌐 Generic Service Endpoints

| Service | URL / Port |
|----------|------------|
| GUI | http://localhost:31800 |
| Grafana | http://localhost:3000 |
| Master Node | VM_IP:32049 |
| Query Node | VM_IP:32349 |
| Operator 1 | VM_IP:32149 |
| Operator 2 | VM_IP:32159 |
| Standalone Operator | VM_IP:32149 |

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
Username: anylog
Password: anylog
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
./ALinstall.sh -d -s
```

Reinstall:

```bash
./ALinstall.sh uninstall
./ALinstall.sh -d -s install
```

Upgrade:

```bash
Edit ALinstall.env and change TAG to the version of Anylog you want to upgrade to
./ALinstall.sh -d -s upgrade
```

View logs:

```bash
docker logs <container_name>
```

---

# 🧰 Tech Stack

- Docker
- AnyLog Data Fabric
- AnyLog Distributed Engine
- REST APIs
- MQTT Ingestion
- SQL Federation
- Grafana
- Web GUI

---

# 📣 Summary

The AnyLog Demo OVA delivers a multi-node distributed data fabric in a single deployable image.

It demonstrates:

- Distributed ingestion  
- Federated SQL queries  
- Blockchain-backed metadata  
- Multi-node orchestration  
- GUI-driven management  

---

⭐ Designed for technical demos, workshops, and proof-of-concept environments.
