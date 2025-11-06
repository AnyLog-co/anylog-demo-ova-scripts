# ▶️ EdgeLake Demo – Quick Start

A minimal, operator-friendly guide to launching and exploring the EdgeLake + AnyLog data fabric.

---

## 🚀 Automatic Start

When the OVA boots, all required containers are launched automatically.

> ✅ No action needed for a first-run demo.

---

## ⚙️ Manual Start (if needed)

Launch all EdgeLake containers with:

```bash
cd ~/Edgelake
./ELstartup.sh
```

This starts:

- **gui-1** – Web UI for monitoring and data management
- **grafana** - Sample Grafana Dashboard
- **edgelake-demo-master** – Control plane  
- **edgelake-demo-query** – Query node (SQL over Edgelake)  
- **edgelake-demo-operator** – Data operator node  
- **edgelake-demo-operator2** – Second data operator node  

---

## 🌐 Service Endpoints

| Service               | Role                  | Endpoint                          |
|-----------------------|-----------------------|-----------------------------------|
| **GUI** (gui-1)       | Web UI                | [http://localhost:3001](http://localhost:3001) |
| **Sample Dashboard** (grafana)       | Sample Dashboard                | [http://localhost:3000](http://localhost:300) |
| **Query Node REST** (edgelake-demo-query) | SQL & Fabric Query     | `vmipaddr:32349` |
| **Operator Node REST** (edgelake-demo-operator) | Data Ingest / Control | `vmipaddr:32149` |
| **Operator2 Node REST** (edgelake-demo-operator2) | Data Ingest / Control | `vmipaddr:32159` |

<details>
<summary>Using the GUI with a node</summary>

Open the GUI and insert the **VM IP:Port** of a Query or Operator node in the Connection dialog, then click **Use**.

</details>

---

## 🛠️ GUI Features

- **Monitor** → Track resources and health across nodes  
- **Add Data** → Load JSON-formatted data into operator nodes  
- **SQL Query** → Build and run SQL queries on the query node  
- **Blockchain Manager** → Inspect blockchain metadata  

---

## 📦 Default Demo Dataset

- **Database:** `new_company`  
- **Table:** `rand_data`  

> This table is pre-populated via a cloud MQTT feed on first launch.

---

## ➕ Adding Your Own Data

1. **Use the GUI (Operator node)**  
   Click **Add Data** and provide JSON-formatted input.

2. **Subscribe to a MQTT broker**  
   [MQTT Background Services](https://github.com/EdgeLake/edgelake.github.io/blob/main/docs/commands/background_services.md#subscribe-to-broker)

3. **Insert via REST API**  
   [REST Insert Examples](https://github.com/EdgeLake/edgelake.github.io/blob/main/docs/examples/rest_examples.md#put-request)

> ⚠️ Ensure you target an **operator** node for data insertion and the **query** node for read/SQL workflows.

---

## 📖 Documentation

- [Getting Started](https://github.com/EdgeLake/edgelake.github.io/blob/main/docs/getting_started.md)  
- [Command Reference](https://github.com/EdgeLake/edgelake.github.io/docs/commmands)  

---

💡 Pro tip: keep this README open on first boot.
---

## 🔐 Credentials

> **Security note:** The default demo **username** is `edgelake` and the **password** is `edgelake`. Change this immediately for any production or networked demo.
