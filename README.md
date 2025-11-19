# MVP-CPEmon – Cloud-Native CPE Monitoring Demo

**Goal:**  
Give a reviewer enough context to go from **zero** to **“can deploy and run the MVP-CPEmon demo”** using only this README and basic Kubernetes knowledge.

---

## 1. Project overview

MVP-CPEmon is a small “telco-style” lab project that simulates how an ISP monitors CPE (home router) devices end-to-end.

It glues together:

- CPE heartbeat simulators (Python, on a separate VM)
- GenieACS (TR-069 ACS, also on that VM)
- A Kubernetes-hosted ingest pipeline (`acs-ingest`, `cpemon-writer`)
- An API / dashboard service (`cpemon-api`)
- A full observability stack (Prometheus, Grafana, Elasticsearch/Kibana)
- Backup & disaster recovery (Velero + MinIO/S3)

The result is a **small but realistic** pipeline you can demo in interviews:

> CPE → GenieACS → Ingress → acs-ingest → MySQL queues → cpemon-writer → cpemon-api → Grafana / Kibana / Velero.

---

## 2. Architecture

### 2.1 Data flow

High-level flow:

- **CPE simulator (vm3)**
  - Sends TR-069 traffic to **GenieACS**.
  - Sends HTTP heartbeats to `/cpe/heartbeat` on **cpemon-api**.

- **GenieACS (vm3)**
  - Manages CPEs.
  - For important events, calls a webhook `/acs/webhook` exposed by the cluster.

- **Kubernetes cluster**
  - **Ingress-NGINX** exposes:
    - `https://api.local` → `cpemon-api`
    - `https://api.local/acs/webhook` → `acs-ingest`
  - **acs-ingest**
    - Validates / normalises ACS events.
    - Writes them into **MySQL queue tables**.
    - Exposes Prometheus metrics (including `acs_webhook_requests_total`, `acs_webhook_errors_total`).
  - **cpemon-api**
    - Ingests CPE heartbeat (`/cpe/heartbeat`).
    - Exposes REST APIs for dashboards.
  - **cpemon-writer**
    - Consumes queue tables and writes into **business tables**.
  - **Prometheus + Grafana**
    - Scrapes metrics from all above components.
    - Provides the main **“CPEmon Pipeline Overview”** dashboard.
  - **Filebeat + Elasticsearch + Kibana**
    - Collect and visualise logs.
  - **Velero + MinIO/S3**
    - Back up `cpemon` namespace + MySQL state.
    - Restore for DR demo.

### 2.2 Mermaid diagram (optional in GitHub)

```mermaid
flowchart LR
  CPE[CPE simulator\n(vm3)] --> ACS[GenieACS]
  ACS -->|/acs/webhook| Ingress[Ingress-NGINX]
  CPE -->|/cpe/heartbeat| Ingress

  Ingress --> ACSI[acs-ingest]
  Ingress --> API[cpemon-api]

  ACSI --> Q[(MySQL\nqueue tables)]
  API --> Q
  Q --> WR[cpemon-writer]
  WR --> DB[(MySQL\nbusiness tables)]

  DB --> DashAPI[cpemon-api\n(dashboards)]

  subgraph Observability
    Prom[Prometheus] --> Graf[Grafana]
    Logs[Filebeat] --> ES[Elasticsearch] --> Kib[Kibana]
  end

  K8s[(Kubernetes)] --- Prom
  DB --- MinIO[(MinIO / S3)]
  K8s --- Velero[Velero]
```

---

## 3. Tech stack

### Platform

- Kubernetes (kubeadm lab cluster)
- MetalLB (LoadBalancer on bare-metal)
- ingress-nginx

### Application services

- `cpemon-api` (Go)
- `cpemon-admin` web UI (served at `https://admin.local`, backed by `cpemon-api`)
- `cpemon-writer` (Go)
- `acs-ingest` (Go)
- GenieACS (Node.js, Docker on vm3)
- CPE heartbeat simulator (Python, Docker on vm3)

### Data layer

- MySQL (queue / business tables)
- MinIO / S3 (MySQL dumps, Velero backup storage)
- Elasticsearch (logs)

### Observability

- Prometheus + kube-prometheus-stack
- Grafana (dashboards in `dashboards/`)
- Filebeat + Elasticsearch + Kibana

### Backup & DR

- Velero
- MinIO / S3-compatible object storage

---

## 4. How to run in your lab cluster

> Assumption: you already have a running cluster and `kubectl` access.

### 4.1 Prerequisites

On your **Kubernetes admin node**:

- `kubectl`, `helm`, `docker`, `velero` installed.
- `~/.kube/config` points to the target cluster.
- `/etc/hosts` on your laptop (and vm3) contains something like:

  ```text
  10.0.0.200 api.local grafana.local kibana.local admin.local
  ```

On **vm3** (CPE/ACS host):

- Docker engine installed.
- Same `/etc/hosts` entry so vm3 can resolve `api.local` to ingress IP.

### 4.2 Deploy the Kubernetes stack

From repo root:

```bash
cd ~/cpemon-mvp
```

**Namespaces**

```bash
kubectl create namespace cpemon     || true
kubectl create namespace monitoring || true
kubectl create namespace logging    || true
kubectl create namespace backup     || true
kubectl create namespace genieacs   || true
```

**Data services**

```bash
kubectl apply -R -f k8s/mysql/
kubectl apply -R -f k8s/minio/
```

**Ingress / MetalLB (if not already present)**

```bash
kubectl apply -R -f k8s/ingress-nginx/
kubectl apply -R -f k8s/metallb/
```

**CPEmon apps**

```bash
kubectl apply -R -f k8s/cpemon/
```

**Observability & cronjobs**

```bash
kubectl apply -R -f k8s/monitoring/
kubectl apply -R -f k8s/logging/
kubectl apply -R -f k8s/cron/
```

> Check directory names against your repo; adjust if they differ.

Verify everything is running:

```bash
kubectl get pods -A
```

### 4.3 Start GenieACS + CPE simulator on vm3

On **vm3**:

```bash
cd ~/cpemon-mvp/vm3
NUM_CPE=5 ./start-vm3-stack.sh
```

The script will:

- Use `acs/docker-compose.yml` to start GenieACS, MongoDB, Redis.
- Build `cpe-sim/Dockerfile` into `cpemon-cpe-sim:latest`.
- Run `cpe-sim-N` containers that send periodic heartbeats to `https://api.local/cpe/heartbeat`.

Check:

```bash
docker ps
docker logs -f cpe-sim-1
```

You should see:

```text
[OK] sent heartbeat ... status=202
```

---

## 5. Demo scenarios (interview-ready)

All helper scripts live in `scripts/`. Make them executable:

```bash
cd ~/cpemon-mvp
chmod +x scripts/*.sh
```

### 5.1 Quick smoke test – `scripts/smoke.sh`

**Goal:** verify cluster + core services are healthy.

```bash
scripts/smoke.sh
```

Roughly checks:

- Key namespaces & Pods are running.
- Ingress / MetalLB are listening on ports **80/443**.
- `https://api.local` responds.
- `cpemon-api` health endpoint.

Use this at the start of a demo: *“environment is clean and working”*.

---

### 5.2 Backlog scenario – `scripts/make_backlog.sh` + Grafana

**Goal:** show what happens when the writer is down and queues build up, then recover.

```bash
HEARTBEAT_COUNT=300 PAUSE_BEFORE_RESUME=30   scripts/make_backlog.sh
```

The script will:

1. Scale `cpemon-writer` to `0` (simulate consumer outage).  
2. Hit `/cpe/heartbeat` many times to build up queue backlog.  
3. Sleep for a while so you can see backlog rising in Grafana.  
4. Scale `cpemon-writer` back to its original replica count and watch backlog drain.

In Grafana’s **CPEmon Pipeline Overview** dashboard, focus on:

- `cpemon-api: HTTP Requests by Status`
- `cpemon-writer: Events (processed / dead)`
- Any queue / lag panels you defined.

---

### 5.3 Backup / Restore DR scenario – `scripts/backup_restore.sh` + Velero

**Goal:** demonstrate using Velero to back up and restore `cpemon-api` and related resources.

```bash
scripts/backup_restore.sh
```

The script:

- Creates a Velero backup for the `cpemon` namespace (name with timestamp).
- Deletes `cpemon-api` Deployment / Service / Ingress to simulate a failure.
- Restores from the backup.
- Waits until restored resources are running again.
- Optionally re-runs `scripts/smoke.sh` as final verification.

This is your DR story: *“we can lose cpemon-api and get it back from backup”*.

---

### 5.4 Admin Web UI demo – `https://admin.local`

**Goal:** show a simple web UI on top of `cpemon-api`, so reviewers see both APIs and a small product-style UI.

**How to use:**

1. Make sure your `/etc/hosts` on your laptop contains:

   ```text
   10.0.0.200 admin.local
   ```

   (Replace `10.0.0.200` with your ingress IP if different.)

2. After the cluster is up and `cpemon-api` is running, open a browser on your laptop and visit:

   ```bash
   https://admin.local
   ```

   If you are using a self-signed certificate, the browser will show a warning — accept it for this lab.

3. In the admin UI you can, for example:

   - See a list of CPE devices and their latest heartbeat status.
   - Click into a CPE to see details (SN, WAN IP, SW version, last-seen timestamp).
   - Cross-check what you see here with:
     - Grafana’s **“CPEmon Pipeline Overview”** dashboard.
     - Kibana logs for the same CPE SN.

---

### 5.5 Extra demos (optional)

- **CPE heartbeat demo – `scripts/demo_cpe_acs.sh`**  
  Focused on **“CPE → cpemon-api → MySQL → cpemon-writer”** without ACS.  
  Good if you want a shorter story.

- **ACS webhook + error metrics – `scripts/acs-webhook-demo.sh`**  
  Sends:

  - valid webhooks (`202`)
  - `invalid_json`
  - `missing_sn`
  - `invalid_signature`

  and drives:

  - `acs_webhook_requests_total`
  - `acs_webhook_errors_total`

  Use this when showcasing the ACS side of the pipeline.

- **Ingress ports check – `scripts/ingress-ports-check.sh`**  
  Shows which process is listening on 80/443, useful when debugging ingress.

---

## 6. Repository structure

At a glance:

```text
.
├── app/              # Go services: cpemon-api, cpemon-writer, acs-ingest
├── k8s/              # All Kubernetes manifests (infra, cpemon, monitoring, logging, cronjobs)
├── backup/           # Velero / DB backup helpers
├── scripts/          # Smoke, backlog, backup_restore, ACS demos, etc.
├── dashboards/       # Grafana dashboard JSON
├── docs/             # Extra docs / screenshots / notes (optional)
├── adr/              # Architecture decision records
├── ops/
│   └── runbooks/     # Operational runbooks for demo
├── sql/              # MySQL schema & migrations
├── vm3/              # vm3-side setup: GenieACS docker-compose + CPE simulator
├── docker/           # Dockerfiles for application images
├── Makefile          # Optional build / lint helpers
└── README.md         # This file
```

---

## 7. What a reviewer should be able to do

After reading this README, someone with **basic Kubernetes experience** should be able to:

- Understand the purpose and architecture of MVP-CPEmon.  
- Deploy the stack on their lab cluster (K8s + vm3).  
- Run at least these three demo scripts:
  - `scripts/smoke.sh`
  - `scripts/make_backlog.sh`
  - `scripts/backup_restore.sh`
- Optionally run `scripts/acs-webhook-demo.sh` to showcase ACS-side metrics.  
- Navigate the Grafana **“CPEmon Pipeline Overview”** dashboard and connect graphs to the underlying architecture.
