# Incident Runbooks – MVP-CPEmon

This document describes practical runbooks for the most likely failure scenarios in the MVP-CPEmon lab environment.

Namespaces and components referenced here:

- **Namespace `cpemon`**: `cpemon-api`, `cpemon-writer`, `acs-ingest`, `mysql`
- **Namespace `monitoring`**: kube-prometheus-stack (`prometheus-kps-*`, `kps-grafana-*`, Alertmanager, node-exporter, kube-state-metrics)
- **Namespace `logging`**: `elasticsearch`, `kibana`, `filebeat` (DaemonSet)
- **Namespace `ingress-nginx`**: `ingress-nginx-controller`
- **Namespace `backup`**: `velero`, node-agent, MySQL backup jobs
- **Namespace `platform`**: `minio`, `echo` test app
- **External VM `vm3`**: GenieACS, CPE simulators

Main dashboard: **Grafana → “CPEmon Pipeline Overview”** (namespace `monitoring`, Pod `kps-grafana-*`).

---

## 1. Queue Backlog Explosion

### Title

Queue backlog explosion between ingest services and `cpemon-writer`.

### Impact

- CPE heartbeats and/or ACS events are **not processed in time**.
- Dashboards and admin UI show **stale CPE state** (last-seen timestamps not updating).
- Alerts may fire on **queue depth** / **processing delay**.

### Possible Causes

- `cpemon-writer` Pods:
  - Crashed, `CrashLoopBackOff`, or not running.
  - Scaled down to `0` replicas (e.g. after a demo).
- MySQL performance issues:
  - Slow queries on queue tables.
  - Lock contention or high CPU.
- Sudden spike in incoming traffic:
  - Too many CPE heartbeats from vm3 simulators.
  - ACS sending a burst of webhook events.
- Misconfiguration:
  - Writer polling interval too low / batch size too small.

### Diagnostics Checklist

1. **Check queue metrics in Grafana**

   - Open **“CPEmon Pipeline Overview”** dashboard.
   - Look for panels showing:
     - Queue depth / backlog.
     - Writer throughput (events processed / dead).
   - Confirm:
     - Backlog trending **up**.
     - Processed events **flat or dropping**.

2. **Check `cpemon-writer` Pod status (namespace `cpemon`)**

   ```bash
   kubectl -n cpemon get deploy cpemon-writer
   kubectl -n cpemon get pods -l app=cpemon-writer -o wide
   ```

   - Any Pods in `CrashLoopBackOff` / `Error` / `Pending`?
   - Are replicas accidentally set to `0`?

3. **Check MySQL health and load (namespace `cpemon`)**

   ```bash
   kubectl -n cpemon get pods -l app=mysql
   kubectl -n cpemon top pod -l app=mysql
   ```

   - CPU / memory extremely high?
   - Any restarts?

   Optionally exec into MySQL and check connections / slow queries:

   ```bash
   kubectl -n cpemon exec -it deploy/mysql -- mysql -uroot -p

   SHOW GLOBAL STATUS LIKE 'Threads_connected';
   SHOW FULL PROCESSLIST;
   ```

4. **Check incoming traffic rate**

   In Grafana:

   - `cpemon-api: HTTP Requests by Status`
   - `acs-ingest: Webhook Requests by Status`

   Look for:

   - A sharp spike in `2xx` request rate.
   - Large amount of `4xx/5xx` which may indicate overload.

5. **Check logs**

   - `cpemon-writer` logs:

     ```bash
     kubectl -n cpemon logs -l app=cpemon-writer --tail=200
     ```

   - Or search in Kibana by:
     - `kubernetes.namespace: "cpemon"`
     - `kubernetes.labels.app: "cpemon-writer"`

### Immediate Actions

> Goal: **stop backlog from growing**, then **resume normal processing**.

1. **Ensure `cpemon-writer` is running**

   - If replicas are `0` (e.g. after a demo):

     ```bash
     kubectl -n cpemon scale deploy cpemon-writer --replicas=2
     ```

   - If Pods are crashing, quickly check recent logs:

     ```bash
     kubectl -n cpemon logs deploy/cpemon-writer --tail=200
     ```

2. **Temporarily scale `cpemon-writer` up**

   - If MySQL looks healthy but backlog is large:

     ```bash
     kubectl -n cpemon scale deploy cpemon-writer --replicas=3
     ```

   - Monitor:
     - Queue depth trending down in Grafana.
     - MySQL CPU / connections not maxed out.

3. **If MySQL is saturated, shed or slow down incoming traffic**

   - On **vm3**:
     - Reduce the number of running CPE simulator containers.
     - Lower heartbeat frequency (if supported by the sim).
   - For ACS traffic:
     - If possible, slow down or temporarily pause some webhook sources.

   As a last resort, scale `cpemon-api` / `acs-ingest` down to reduce ingest speed (accepting some `5xx`/timeouts under extreme conditions).

4. **Communicate impact**

   - Note: CPE data may be **delayed**, but usually **not lost** as long as queue tables remain intact.
   - Inform stakeholders: “processing lag is X minutes; backlog is being drained now.”

### Follow-up / Prevention

1. **Tune writer behaviour**

   - Review and adjust:
     - Batch size for queue processing.
     - Polling interval.
   - Consider adding metrics like:
     - Batch duration.
     - Batch size.

2. **Alerting on earlier symptoms**

   - Add Prometheus alerts on:
     - Queue depth above threshold for N minutes.
     - `cpemon-writer` replicas `== 0` unexpectedly.
   - Ensure the CPEmon dashboard clearly shows:
     - Backlog over time.
     - Writer throughput.

3. **Optimize MySQL**

   - Add/refine indexes on queue tables.
   - Archive or purge processed rows regularly.
   - Review slow query logs.

4. **Traffic control in demos**

   - When running heavy demo load from vm3:
     - Increase number of CPE simulators gradually.
     - Watch queue depth and MySQL metrics.
     - Stop increasing load if metrics approach limits.

---

## 2. Elasticsearch Disk Full

### Title

Elasticsearch disk full / cluster in red or yellow state.

### Impact

- Logs stop being indexed or are partially indexed.
- Kibana shows:
  - `RED` or `YELLOW` cluster health.
  - Errors when viewing recent logs.
- Troubleshooting incidents becomes harder because **new logs are missing**.

### Possible Causes

- Single-node Elasticsearch running out of disk:
  - Log volume higher than expected.
  - No retention policy applied.
- Large or many indices kept forever.
- Misconfigured Filebeat:
  - Collecting too many namespaces.
  - Very noisy logs not filtered out.

### Diagnostics Checklist

1. **Check Elasticsearch Pod and logs (namespace `logging`)**

   ```bash
   kubectl -n logging get pods | grep elasticsearch
   kubectl -n logging logs deploy/elasticsearch --tail=100
   ```

   - Any OOM / disk-related errors?

2. **Check cluster health from inside the Pod**

   ```bash
   kubectl -n logging exec -it deploy/elasticsearch --      curl -s localhost:9200/_cluster/health?pretty
   ```

   - Look at `status` (`green`, `yellow`, `red`) and any `unassigned_shards`.

3. **Check disk usage inside Elasticsearch container**

   ```bash
   kubectl -n logging exec -it deploy/elasticsearch -- df -h
   ```

   - Focus on the ES data path (e.g. `/usr/share/elasticsearch/data`).

4. **List indices and sizes**

   ```bash
   kubectl -n logging exec -it deploy/elasticsearch --      curl -s 'localhost:9200/_cat/indices?v'
   ```

   - Look for:
     - Very large indices.
     - Many old `filebeat-*` indices that you no longer need.

5. **Check Kibana (namespace `logging`)**

   - Open Kibana.
   - Look at:
     - Cluster health indicators.
     - Index management screens for any warnings.

### Immediate Actions

> Goal: **free disk quickly so indexing and searches resume**.

1. **Delete old / non-critical indices**

   - From inside the ES Pod or via port-forward:

     ```bash
     # Example: delete very old filebeat indices (adjust pattern)
     kubectl -n logging exec -it deploy/elasticsearch --        curl -XDELETE 'localhost:9200/filebeat-2024.01.*'
     ```

   - Start by deleting the **oldest** indices that are not needed for current debugging.

2. **If disk is completely full and ES will not start cleanly**

   - Option 1: increase PersistentVolume size (if storage class supports expansion), then restart the Pod.
   - Option 2 (last resort): manually remove some old data directories under the ES data path, then let ES re-create indices (this may lose old logs).

3. **Temporarily reduce log ingestion**

   Filebeat in this lab runs as a **DaemonSet** in `logging`:

   - Check the DaemonSet:

     ```bash
     kubectl -n logging get daemonset filebeat
     ```

   - If your Kubernetes version supports scaling DaemonSets:

     ```bash
     kubectl -n logging scale daemonset/filebeat --replicas=0
     ```

   - If scaling is not supported, you can temporarily delete the DaemonSet and re-apply it later from your manifests:

     ```bash
     kubectl -n logging delete daemonset filebeat
     ```

4. **Verify recovery**

   - Check disk space again:

     ```bash
     kubectl -n logging exec -it deploy/elasticsearch -- df -h
     ```

   - Check cluster health:

     ```bash
     kubectl -n logging exec -it deploy/elasticsearch --        curl -s localhost:9200/_cluster/health?pretty
     ```

   - Confirm Kibana can show fresh logs and no new indexing errors.

### Follow-up / Prevention

1. **Retention strategy**

   - Decide how many days of logs you need (e.g. 7–14 days for lab).
   - Regularly delete indices older than that via:
     - A simple CronJob hitting ES delete APIs.
     - Or manual cleanup during maintenance.

2. **Index Lifecycle Management (optional)**

   - For more automation, configure ILM policies:
     - `hot` phase: keep recent data.
     - `delete` phase: automatically remove data after N days.

3. **Tune what you log**

   - Reduce noisy logs at source:
     - Avoid debug-level logs in this lab unless needed.
     - Exclude non-essential namespaces from Filebeat config.

4. **Storage capacity**

   - If Elasticsearch is consistently close to full:
     - Allocate a larger PV.
     - Or move ES to a storage class with more capacity.

---

## 3. MySQL Connection Spike

### Title

MySQL connection spike / too many connections.

### Impact

- Applications (`cpemon-api`, `acs-ingest`, `cpemon-writer`) log errors such as:
  - “too many connections”
  - “cannot connect to MySQL”
- HTTP APIs may return `5xx` errors.
- Queue processing slows down or stops.
- Overall platform becomes unstable if DB is starved.

### Possible Causes

- Misbehaving Pod(s) opening too many connections:
  - Connection leak in application code.
  - Extremely high request rate causing too many short-lived connections.
- Connection pool misconfiguration:
  - No pooling (each request opens a new connection).
  - Too many connections allowed per Pod.
- MySQL `max_connections` set too low for current load.

### Diagnostics Checklist

1. **Check application symptoms**

   - In Grafana:
     - `cpemon-api: HTTP Requests by Status` (look for `5xx`).
     - `acs-ingest: Webhook Requests by Status`.
   - In Kibana:
     - Search for logs containing:
       - `"too many connections"`
       - MySQL error codes such as `1040`.

2. **Check MySQL Pod status (namespace `cpemon`)**

   ```bash
   kubectl -n cpemon get pods -l app=mysql
   kubectl -n cpemon top pod -l app=mysql
   ```

   - Any restarts?
   - CPU or memory consistently maxed out?

3. **Check MySQL connection count and limits**

   ```bash
   kubectl -n cpemon exec -it deploy/mysql -- mysql -uroot -p

   SHOW VARIABLES LIKE 'max_connections';
   SHOW GLOBAL STATUS LIKE 'Threads_connected';
   SHOW GLOBAL STATUS LIKE 'Threads_running';
   SHOW FULL PROCESSLIST;
   ```

   - Is `Threads_connected` close to or above `max_connections`?
   - Are there many connections from a single application Pod or IP?

4. **Check which Pods are generating load**

   ```bash
   kubectl -n cpemon get pods
   ```

   - Focus on:
     - `cpemon-api-*`
     - `acs-ingest-*`
     - `cpemon-writer-*`
   - Check their logs for tight retry loops or errors.

### Immediate Actions

> Goal: **restore DB connectivity**, then **find and fix the cause**.

1. **Restart or scale down misbehaving Pods**

   - If one app is clearly leaking connections or retrying endlessly:
     - Restart the Deployment:

       ```bash
       kubectl -n cpemon rollout restart deploy/cpemon-api
       ```

     - Or temporarily scale it down:

       ```bash
       kubectl -n cpemon scale deploy/cpemon-api --replicas=0
       ```

   - Re-check `Threads_connected` and `Threads_running` afterwards.

2. **Temporarily raise `max_connections` (only if safe)**

   - Ensure MySQL Pod has enough memory/CPU headroom.
   - Inside MySQL:

     ```sql
     SET GLOBAL max_connections = 300;
     SHOW VARIABLES LIKE 'max_connections';
     ```

   - Note: this change is **not persistent** across restarts unless set in the MySQL config.

3. **Throttle incoming traffic from vm3**

   - On `vm3`:
     - Reduce number of CPE simulator containers.
     - Lower heartbeat frequency.
   - For ACS:
     - If possible, temporarily reduce webhook rate.

4. **Verify recovery**

   - In MySQL:

     ```sql
     SHOW GLOBAL STATUS LIKE 'Threads_connected';
     ```

   - Confirm application Pods no longer log MySQL connection errors.
   - Confirm HTTP `5xx` rates in Grafana have dropped.

### Follow-up / Prevention

1. **Connection pooling**

   - Ensure all Go services (`cpemon-api`, `acs-ingest`, `cpemon-writer`) use:
     - A reasonable max open connections.
     - Proper idle connection limits.
   - Expose DB connection stats via metrics if possible.

2. **Reasonable `max_connections`**

   - Set `max_connections` to a realistic value for this lab:
     - High enough for expected load.
     - Low enough to protect MySQL from being overwhelmed.

3. **Query optimisation**

   - Review slow query logs.
   - Add indexes for frequently accessed columns (e.g. queue selectors).
   - Avoid long-running transactions or holding locks unnecessarily.

4. **Alerting**

   - Add Prometheus alerts on:
     - MySQL `Threads_connected / max_connections` ratio (e.g. > 80% for 5–10 minutes).
     - High `5xx` rate due to DB errors.
   - Add a Grafana panel showing MySQL connections over time.

5. **Traffic shaping in demos**

   - When running large demo loads:
     - Increase CPE simulators gradually.
     - Watch DB metrics and stop increasing when near limits.
