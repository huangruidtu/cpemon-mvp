## Demo & 面试用一键脚本说明（`scripts/`）

所有脚本都在 `scripts/` 目录下，建议先：

```bash
chmod +x scripts/*.sh
```

---

### 1. 集群 & Ingress & cpemon-api 烟囱测试（`scripts/smoke.sh`）

**作用（面试可说）：**

* 一键检查：K8s 节点、命名空间、ingress-nginx、MetalLB、`api.local` DNS、`cpemon-api` 健康。
* 证明集群基础设施和应用入口是健康的。

**怎么跑：**

```bash
cd ~/cpemon-mvp
scripts/smoke.sh
```

**常用可选参数：**

* `NAMESPACE`：cpemon-api 所在命名空间，默认 `cpemon`
* `SN`：测试用的 CPE SN，默认 `CPE123`
* `BASE_URL`：cpemon-api 访问入口，默认 `https://api.local`

示例：

```bash
NAMESPACE=cpemon SN=CPE123 BASE_URL=https://api.local scripts/smoke.sh
```

---

### 2. CPE → cpemon-api 心跳演示（`scripts/demo_cpe_acs.sh`）

**作用：**

* 用 `curl` 模拟 CPE 往 `/cpe/heartbeat` 发送一串心跳。
* 然后调用 `/api/cpe/{sn}` 查这台 CPE 的最新状态。
* 配合 Grafana 的 `cpemon-api: HTTP Requests`、`cpemon-writer: Events` panel 做数据流演示。

**怎么跑：**

```bash
cd ~/cpemon-mvp
scripts/demo_cpe_acs.sh
```

**常用可选参数：**

* `API_HOST`：API 前缀，默认 `https://api.local`
* `CPE_SN`：演示用 SN，默认 `CPE-TR069-DEMO`
* `COUNT`：发送多少次心跳，默认 `30`
* `SLEEP_SEC`：每次心跳间隔秒数，默认 `2`

示例（面试演示推荐）：

```bash
API_HOST=https://api.local CPE_SN=CPE-TR069-DEMO COUNT=30 SLEEP_SEC=2 \
  scripts/demo_cpe_acs.sh
```

> 跑之前可以先打开 Grafana 的 “CPEMon Pipeline Overview” dashboard，看 `cpemon-api` / `cpemon-writer` 曲线变化。

---

### 3. ACS Webhook + 错误指标演示（`scripts/acs-webhook-demo.sh`）

**作用：**

* 一键向 `/acs/webhook` 发送：

  * 一批正常请求（202）
  * 一批 `invalid_json` 错误
  * 一批 `missing_sn` 错误
  * 一批 `invalid_signature` 错误
* 驱动 Prometheus 指标：

  * `acs_webhook_requests_total{code="202"}`
  * `acs_webhook_errors_total{reason="invalid_json"|"missing_sn"|"invalid_signature"}`

**标准用法（通过 port-forward）：**

1. 终端 A：

   ```bash
   kubectl -n cpemon port-forward deploy/acs-ingest 18080:8080 19100:9100
   ```

2. 终端 B：

   ```bash
   cd ~/cpemon-mvp
   scripts/acs-webhook-demo.sh
   ```

**可选参数：**

* `COUNT`：每种场景发送次数，默认 `5`
* `ACS_WEBHOOK_URL`：Webhook 地址，默认 `http://127.0.0.1:18080/acs/webhook`

示例：

```bash
# 每种发 20 条
COUNT=20 scripts/acs-webhook-demo.sh

# 在 vm3 上直接打 ingress
ACS_WEBHOOK_URL="https://api.local/acs/webhook" COUNT=10 \
  scripts/acs-webhook-demo.sh
```

> 然后在 Grafana 看：
>
> * “ACS Webhook Requests by Status”
> * “ACS Webhook Errors by Reason”

---

### 4. 队列 backlog / lag 演示（`scripts/make_backlog.sh`）

**作用：**

* 暂停 `cpemon-writer`（scale 到 0）。
* 向 `/cpe/heartbeat` 打一大波心跳，制造队列 backlog。
* 停几秒方便在 Grafana 观察 backlog 上升。
* 恢复 `cpemon-writer` 副本数，看 backlog 慢慢被消费掉。

**怎么跑：**

```bash
cd ~/cpemon-mvp
scripts/make_backlog.sh
```

**常用可选参数：**

* `APP_NAMESPACE`：默认 `cpemon`
* `WRITER_DEPLOYMENT`：默认 `cpemon-writer`
* `HEARTBEAT_URL`：完整 heartbeat URL；不设则用 `API_BASE_URL + HEARTBEAT_PATH`
* `API_BASE_URL`：默认 `https://api.local`
* `HEARTBEAT_PATH`：默认 `/cpe/heartbeat`
* `HEARTBEAT_COUNT`：心跳总数，默认 `200`
* `HEARTBEAT_DELAY`：每条间隔秒数，默认 `0.05`
* `PAUSE_BEFORE_RESUME`：打完流量后暂停多久再恢复 writer，默认 `20` 秒

示例（面试 demo 推荐）：

```bash
HEARTBEAT_COUNT=300 PAUSE_BEFORE_RESUME=30 \
  scripts/make_backlog.sh
```

> 一边跑，一边在 Grafana 看：
>
> * “队列深度 / lag” panel 先上升（writer=0），再下降（writer 恢复）。

---

### 5. Velero 备份 & 恢复演示（`scripts/backup_restore.sh`）

**作用：**

* 一键演示 Kubernetes 级别的备份恢复：

  1. 用 Velero 备份 `cpemon` 命名空间。
  2. 删除 `cpemon-api` 的 Deployment/Service/Ingress，模拟故障。
  3. 用刚才的备份恢复。
  4. 验证 `cpemon-api` 恢复正常。
  5. 如有 `scripts/smoke.sh`，顺便跑一遍做最终验证。

**先决条件：**

* 已安装 Velero（CLI + CRDs），有 `backup` 命名空间。
* `velero` 命令在 `PATH` 中可用。

**怎么跑：**

```bash
cd ~/cpemon-mvp
scripts/backup_restore.sh
```

脚本会自动：

* 创建一个带时间戳的 backup 名；
* 等待备份完成；
* 删除 `cpemon-api` 相关资源；
* 创建 restore；
* 等待恢复完成；
* 显示恢复后的 Deployment/Pod 状态；
* 如果 `scripts/smoke.sh` 可执行，会自动跑一次 smoke。

**可选参数：**

* `APP_NAMESPACE`：默认 `cpemon`
* `VELERO_NAMESPACE`：默认 `backup`
* `API_DEPLOYMENT` / `API_SERVICE` / `API_INGRESS`：默认都为 `cpemon-api`
* `BACKUP_NAME` / `RESTORE_NAME`：不设时自动带时间戳生成

---

### 6. Ingress 80/443 端口检查（`scripts/ingress-ports-check.sh`）

**作用：**

* 快速查看当前节点上 80 / 443 端口由谁监听（验证 ingress-controller 是否绑定成功）。

**怎么跑：**

```bash
cd ~/cpemon-mvp
scripts/ingress-ports-check.sh
```

> 可能需要 sudo，会自动尝试 `ss` 或 `netstat`。

