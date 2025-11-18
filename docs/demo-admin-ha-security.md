# CPEmon Admin + HA + Security Demo

This document is a step-by-step script for a 5–10 minute live demo.
It shows:

* The `/admin` cockpit page.
* High-availability behaviour of `cpemon-api` and `acs-ingest`.
* Security controls: Basic Auth, Ingress IP whitelist, and Calico NetworkPolicies.

All commands are run from `k8s-master1` unless stated otherwise.

---

## 0. Prerequisites

Before the demo, verify:

1. **Cluster & Calico are healthy**

   ```bash
   kubectl get nodes
   kubectl -n kube-system get pods | grep -i calico
   ```

2. **Host name resolution**

   On your laptop / jump host, `/etc/hosts` contains:

   ```text
   10.0.0.200  api.local admin.local grafana.local kibana.local
   ```

3. **Admin credentials**

   ```text
   username: admin
   password: supersecret
   ```

4. **Core services are up**

   ```bash
   kubectl -n cpemon get deploy cpemon-api acs-ingest cpemon-writer
   kubectl -n cpemon get pdb
   kubectl -n cpemon get networkpolicy
   ```

---

## 1. Admin cockpit (`/admin`)

### 1.1 Prove Basic Auth protection

Terminal:

```bash
# 1) No credentials → 401
curl -k -I https://admin.local/admin

# 2) Wrong credentials → 401
curl -k -I -u wrong:wrong https://admin.local/admin

# 3) Correct admin credentials → 200
curl -k -I -u admin:supersecret https://admin.local/admin
```

Talk track:

> The `/admin` endpoint is not anonymous.
> Without valid credentials NGINX returns `401` and a `WWW-Authenticate: Basic` header.
> Only the `admin` account is allowed in this demo.

### 1.2 Show the admin page in the browser

Steps:

1. Open `https://admin.local/admin` in the browser.
2. When prompted, log in with `admin / supersecret`.

Explain the page:

* **Search CPE** – search by serial number (SN), e.g. `CPE123`.
* **Current status** – last heartbeat for this SN (WAN IP, SW version, CPU/mem, timestamp).
* **Recent history** – table with previous heartbeats for this SN.
* **Monitoring / Logs** – buttons that open:

  * Grafana home or CPEmon dashboards.
  * Kibana Discover view (optionally filtered by SN).

### 1.3 End-to-end “CPE investigation” flow

In the browser:

1. In the search box, enter a sample SN such as `CPE123` and click **Search**.
2. Point out:

   * Current status panel.
   * Recent history entries.
3. Click **Open Grafana**:

   * Show the global CPEmon metrics dashboard.
4. Click **Open Kibana**:

   * Show logs for the CPEmon namespace.
   * Optionally filter by `sn:"CPE123"` to show device-specific logs.

Talk track:

> From the admin page an operator can go from a CPE ID → current state → history → metrics → logs in a few clicks.

---

## 2. HA behaviour for `cpemon-api` and `acs-ingest`

Goal: show that draining the worker node does not break the API, because master-hosted replicas keep serving traffic.

### 2.1 Show current replica placement

```bash
kubectl -n cpemon get pods -o wide | egrep 'cpemon-api|acs-ingest'
```

Example output (your pod names will differ):

```text
acs-ingest-...   1/1  Running  k8s-master1
acs-ingest-...   1/1  Running  k8s-worker1
cpemon-api-...   1/1  Running  k8s-master1
cpemon-api-...   1/1  Running  k8s-worker1
```

Explain:

> Each of `cpemon-api` and `acs-ingest` runs with 2 replicas.
> Node affinity prefers worker nodes, but at least one replica can fall back to the master node for resilience.

### 2.2 Start a client loop calling `/healthz`

Terminal 1 – port-forward the Service:

```bash
kubectl -n cpemon port-forward svc/cpemon-api 18080:8080
```

Terminal 2 – call `/healthz` in a loop:

```bash
watch -n1 'curl -s http://localhost:18080/healthz'
```

Expected response:

```json
{"service":"cpemon-api","status":"ok"}
```

### 2.3 Drain the worker node

Terminal 3:

```bash
kubectl drain k8s-worker1 --ignore-daemonsets --delete-emptydir-data
```

While the drain is running:

* Keep the `watch` window visible – `/healthz` should continue to return `status":"ok"`.
* After the drain completes, check pod placement again:

```bash
kubectl -n cpemon get pods -o wide | egrep 'cpemon-api|acs-ingest'
```

Explain:

> Even while the worker node is drained, the `cpemon-api` Service stays up because a replica is running on the master node.
> In a real production setup we would also have multiple ingress / load balancer instances; here the demo focuses on the CPEmon workloads.

Finally bring the worker back:

```bash
kubectl uncordon k8s-worker1
```

---

## 3. Security controls

This section ties together the different security layers:

* Basic Auth on `/admin`.
* IP whitelist on the Ingress.
* Calico NetworkPolicies inside the `cpemon` namespace.

### 3.1 Basic Auth recap

Remind the audience:

* Without credentials or with wrong credentials, `/admin` returns `401`.
* With `admin / supersecret`, the login succeeds and the HTML admin page is returned.

(You already demonstrated the curl commands in section 1.1.)

### 3.2 Ingress IP whitelist for `admin.local`

Show the Ingress snippet (from `k8s/ingress/cpemon-admin-ingress.yaml`):

```yaml
nginx.ingress.kubernetes.io/whitelist-source-range: 10.0.0.0/24
```

Explain:

> Only clients from `10.0.0.0/24` can reach `/admin`.
> Requests from other networks receive `403 Forbidden` from NGINX.

Demo:

1. **From the node (allowed range)**

   ```bash
   curl -k -I https://admin.local/admin
   ```

   Expect: `401` (if no credentials) or `200` (with Basic Auth), but **not** `403`.

2. **From inside a Pod (blocked)**

   ```bash
   kubectl -n cpemon run curl-test --rm -it \
     --image=curlimages/curl --command -- sh
   ```

   Inside the pod:

   ```bash
   curl -k -I https://admin.local/admin
   ```

   Expect: `403 Forbidden` (blocked by IP whitelist).

   Exit the pod shell; the pod is deleted automatically because of `--rm`.

### 3.3 Calico NetworkPolicies for core services

First, list policies:

```bash
kubectl -n cpemon get networkpolicy
```

You should see something like:

```text
NAME                       POD-SELECTOR                                   AGE
cpemon-default-deny-egress <all>                                          ...
cpemon-allow-core-egress   app in (cpemon-api,acs-ingest,cpemon-writer)   ...
```

Explain the design:

* `cpemon-default-deny-egress`

  * Applies to all pods in `cpemon` (`podSelector: {}`).
  * `policyTypes: [Egress]` with no rules → all egress is denied by default.

* `cpemon-allow-core-egress`

  * Applies only to `app in (cpemon-api, acs-ingest, cpemon-writer)`.
  * Allows egress to:

    * `kube-dns` in `kube-system` (53/TCP and 53/UDP) for DNS.
    * `mysql` in `cpemon` namespace (3306/TCP).
    * Prometheus service in `monitoring` namespace (9090/TCP).
    * Elasticsearch service in `logging` namespace (9200/TCP).

#### 3.3.1 Allowed pod connectivity test

Create a pod that matches the allow policy (labelled as `cpemon-api`):

```bash
kubectl -n cpemon run bb-allowed \
  --image=busybox:1.37 --restart=Never \
  --labels="app=cpemon-api" \
  --command -- sh -c "sleep 3600"
```

Once it is `Running`, open a shell:

```bash
kubectl -n cpemon exec -it bb-allowed -- sh
```

Inside the pod, test MySQL connectivity (service name may vary; adapt if needed):

```sh
nc -vz mysql 3306
```

Optional: test Prometheus and Elasticsearch as well, using your actual service names:

```sh
# Prometheus example
# nc -vz kps-kube-prometheus-stack-prometheus.monitoring.svc.cluster.local 9090

# Elasticsearch example
# nc -vz elasticsearch.logging.svc.cluster.local 9200
```

These should succeed (connection open).

Exit the shell:

```sh
exit
```

#### 3.3.2 Blocked pod connectivity test

Create a pod that does **not** match the allow policy:

```bash
kubectl -n cpemon run bb-blocked \
  --image=busybox:1.37 --restart=Never \
  --labels="app=test-blocked" \
  --command -- sh -c "sleep 3600"
```

Open a shell:

```bash
kubectl -n cpemon exec -it bb-blocked -- sh
```

Inside the pod, try the same MySQL test:

```sh
nc -vz mysql 3306
```

Expected result: the connection should fail (timeout / no route), because egress is blocked by the default-deny policy and this pod is **not** in the allowed set.

Exit the shell:

```sh
exit
```

Clean up the test pods:

```bash
kubectl -n cpemon delete pod bb-allowed bb-blocked
```

Talk track:

> Only the core workloads (`cpemon-api`, `acs-ingest`, `cpemon-writer`) are allowed to talk to MySQL / Prometheus / Elasticsearch.
> A random pod in the `cpemon` namespace cannot reach those backends because of the Calico NetworkPolicies.

---

## 4. Cleanup

If you ran the HA drain demo, make sure the worker is uncordoned:

```bash
kubectl uncordon k8s-worker1 || true
```

Remove any leftover test pods (if they still exist):

```bash
kubectl -n cpemon delete pod bb-allowed bb-blocked curl-test --ignore-not-found
```

---

## 5. Short interview talk track

If you only have ~5 minutes to explain the project, you can summarise like this:

1. **Admin cockpit**

   * “We have an `/admin` cockpit behind Basic Auth.
     Without credentials you get a 401; with `admin/supersecret` you see the admin UI.
     From there you can search a CPE by SN, see its current status and history, and jump directly to Grafana and Kibana.”

2. **High availability**

   * “`cpemon-api` and `acs-ingest` each run with 2 replicas, scheduled across worker + master using node affinity, tolerations and PDBs.
     When I drain the worker node, traffic continues via the master-hosted replicas and `/healthz` keeps returning OK.”

3. **Security**

   * “The admin endpoint is protected at multiple layers:

     * HTTP Basic Auth on `/admin`.
     * An Ingress IP whitelist so only operators from a specific subnet can reach it.
     * Calico NetworkPolicies in the `cpemon` namespace: egress is default-deny, and only the core services are allowed to talk to MySQL, Prometheus and Elasticsearch.
       A random pod inside the namespace cannot reach those backends.”

This completes the demo story: **admin UX + HA + security** for the CPEmon MVP.

