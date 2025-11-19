太棒的收官题！我把我们最近聊天里你**反复追问**和**经常踩坑**的点，按 SRE 能力图谱整理成一份“**高频疑问 + 必会知识 + 常用命令清单**”。不嫌多版，够你反复复习、贴到知识库/Jira/Wiki 都合适。

---

# 一、你反复问到/卡住的地方（提炼要点 + 记忆钩子）

1. **K8s 上下文/命名空间**

* 现状：`kubernetes-admin@kubernetes`；生产可用 `kubectl config set-context <ctx> --namespace=<ns>` 做**工作命名空间**，减少 `-n`。
* 记忆钩子：*人到哪儿（context），事到哪儿（namespace）。*

2. **StorageClass / PVC Pending（WaitForFirstConsumer）**

* 现象：`WaitForFirstConsumer`；原因：需要**真正的 Pod**绑上 PVC 才能选节点/落盘。
* 口诀：*没有消费者，卷不落地*。

3. **命名空间分层（platform vs cpemon）**

* platform=**平台能力**（ingress、minio、监控等），cpemon=**业务工作负载**（mysql、api、writer…）。
* 好处：RBAC/资源配额拆分，升级/回滚边界清晰。

4. **为什么要 MySQL 两套账号（root + app）**

* root 仅运维/初始化；应用走最小权限 app 账号（读写自身库）。
* 口诀：*人管根（root），应用用（app）。*

5. **Helm 与“手写 YAML”两种部署方式**

* Helm=快、带模板；手写=可控、无外部依赖。MVP遇镜像问题时可**降级手写**保交付。

6. **Bitnami 镜像拉取失败 / tag 不存在**

* 现象：`manifest unknown` / `ImagePullBackOff`。
* 处理：`kubectl get sts/deploy -o jsonpath` 看实际 tag → 换**官方镜像**（如 `mysql:8.4`）或指定**可用 tag**。

7. **DNS/连通性三连**

* `getent hosts <svc>` → `nc -zv host port` 或 `echo >/dev/tcp/host/port` → 实际业务命令（`mysql -h…`）。
* 口诀：*解析—端口—协议*。

8. **`-p"$PASS"` 变交互要密码**

* 变量为空就变交互；改用 `env MYSQL_PWD=… mysql …` 更稳更安全。

9. **ConfigMap 放哪儿？**

* 放项目 `k8s/<component>/configmap.yaml`；容器挂载到官方约定目录（如 `mysql:/etc/mysql/conf.d/*.cnf`）。

10. **MinIO 的 mc 容器“不会 sh”**

* 因为 `ENTRYPOINT=mc`。要 `--command -- sh -lc "mc … && mc …"` 或用 `MC_HOST_local=…` 环境变量**免 alias**。

11. **跨命名空间引用 Secret 不可行**

* K8s 不支持跨 ns 取 Secret；在消费方 ns 复制**连接信息**（不是复制平台 Secret 本体）。

12. **CronJob 正确等待 & 本地时区**

* Pod 成功退出 `Completed` 不等于 `Ready`；用 Job/`wait job … Complete`。`spec.timeZone` + 容器 `TZ` 一致化日期。

---

# 二、SRE 必会知识地图（落到实操）

**A. 集群与调度**

* Context/Namespace、Node 亲和性/污点容忍、Pod（资源 requests/limits、PDB、HPA）。
* Readiness/Liveness/Startup 探针；滚动发布与回滚（`rollout`）。

**B. 网络与入口**

* ClusterIP/Headless、Service→Endpoints、CoreDNS、Ingress（hostNetwork on worker 的模式）、/etc/hosts 灰度。
* 排障路径：DNS → Endpoints → Pod → Node → 网段/路由。

**C. 存储**

* StorageClass（local-path）、PVC/PV 绑定、`WaitForFirstConsumer`、访问模式（RWO/RWX）、emptyDir 共享容器。

**D. 配置与密钥**

* ConfigMap（文件挂载/环境变量）、Secret（Opaque、stringData）、命名、标签与分组、不可跨 ns。

**E. 数据层与备份**

* MySQL：初始化用户/库、`mysqldump`、一致性快照、字符集/排序规则、索引/幂等键。
* MinIO（S3 兼容）：bucket 规划、前缀命名、`mc` 客户端、保留策略。

**F. 可观测性（MVP 版）**

* 日志（ELK/Loki 二选一即可）、指标（Prometheus+Grafana）、报警（基本规则：存活、错误比、队列堆积）。

**G. 可靠性与恢复**

* 备份/恢复流程、RPO/RTO 目标、演练（手工触发 Job、恢复 SQL、校验数据）。
* 回滚：`rollout undo`；暂停：`suspend CronJob`。

**H. 安全与最小权限**

* 账号分离、最小权限、Secrets 模板化（envsubst/SOPS/SealedSecrets）、审计标签。

---

# 三、命令速查（按场景）

## 1) 上下文/命名空间

```bash
kubectl config get-contexts
kubectl config set-context --current --namespace=cpemon
kubectl config use-context kubernetes-admin@kubernetes
```

## 2) 资源与排障

```bash
kubectl get nodes -o wide
kubectl get pods -A --field-selector=status.phase!=Running
kubectl get events -A --sort-by=.lastTimestamp | tail -n 50
kubectl describe pod <pod> -n <ns>
kubectl logs <pod> -n <ns> -c <container> --tail=200
```

## 3) Service / DNS / 端口

```bash
kubectl -n <ns> get svc,ep
kubectl -n <ns> exec <pod> -- getent hosts mysql
kubectl -n <ns> exec <pod> -- bash -lc '(echo >/dev/tcp/mysql/3306) && echo OK || echo FAIL'
```

## 4) 存储

```bash
kubectl get sc
kubectl -n <ns> get pvc
kubectl -n <ns> describe pvc <name>
```

## 5) 部署/发布/回滚

```bash
kubectl -n <ns> rollout status deploy/<name>
kubectl -n <ns> rollout history deploy/<name>
kubectl -n <ns> rollout undo deploy/<name> [--to-revision=N]
kubectl -n <ns> rollout restart deploy/<name>
```

## 6) Helm（查 chart、指定镜像）

```bash
helm repo list && helm repo update
helm show values bitnami/mysql | less
helm -n cpemon upgrade --install mysql bitnami/mysql -f values.yaml \
  --set image.repository=mysql --set image.tag=8.4 --set image.pullPolicy=IfNotPresent
```

## 7) MySQL（客户端与健康）

```bash
APP_PW=$(kubectl -n cpemon get secret mysql-auth -o jsonpath='{.data.mysql-password}' | base64 -d)
kubectl -n cpemon run mysql-tester --restart=Never --image=mysql:8.4 -- sleep 3600
kubectl -n cpemon wait pod/mysql-tester --for=condition=Ready --timeout=120s

kubectl -n cpemon exec -it mysql-tester -- \
  env MYSQL_PWD="$APP_PW" mysql -hmysql -ucpemon -e "SELECT 1;" cpemon

ROOT_PW=$(kubectl -n cpemon get secret mysql-auth -o jsonpath='{.data.mysql-root-password}' | base64 -d)
kubectl -n cpemon exec -it deploy/mysql -- \
  mysql -h127.0.0.1 -uroot -p"$ROOT_PW" -e "SHOW VARIABLES LIKE 'binlog_format';"
```

## 8) MinIO / mc

```bash
# 一次性别名（不暴露命令行明文）
MINIO_ACCESS=$(kubectl -n platform get secret minio-auth -o jsonpath='{.data.root-user}' | base64 -d)
MINIO_SECRET=$(kubectl -n platform get secret minio-auth -o jsonpath='{.data.root-password}' | base64 -d)
kubectl -n platform run --rm -it mc --restart=Never --image=minio/mc:latest \
  --env=MC_HOST_local="http://$MINIO_ACCESS:$MINIO_SECRET@minio.platform.svc.cluster.local:9000" \
  --command -- sh -lc 'mc ls local && mc ls local/mysql-backup/'
```

## 9) CronJob / Job

```bash
kubectl -n cpemon get cronjob db-backup -o wide
kubectl -n cpemon create job "db-backup-manual-$(date +%s)" --from=cronjob/db-backup
kubectl -n cpemon get pods -l app=db-backup -w
kubectl -n cpemon logs <pod> -c dumper
kubectl -n cpemon logs <pod> -c uploader
kubectl -n cpemon patch cronjob/db-backup -p '{"spec":{"suspend":true}}'  # 暂停
```

## 10) 常用 Linux / 工具

```bash
base64 -d <<<"..."         # 解码
jq .                       # JSON 美化/解析
gzip -9 < a.sql > a.sql.gz # 压缩
curl -I http://api.local   # 测试入口
```

---

# 四、常见故障 → 快速诊断矩阵

* **ImagePullBackOff**：看事件→校验镜像名/仓库/tag→尝试 `docker pull` 在节点→换官方镜像。
* **Pod Pending（卷）**：PVC `WaitForFirstConsumer` → 启动引用该 PVC 的 Pod。
* **Service 无响应**：查 `Endpoints` 是否为空 → Pod 探针/labels 对不对 → `logs`/`describe`。
* **`mysql` 连不通**：DNS→3306→`SELECT 1`；变量空导致 `-p` 交互→改 `MYSQL_PWD`。
* **mc “sh not found”**：给 `--command -- sh -lc` 覆盖 entrypoint 或用 `MC_HOST_local=…`。
* **跨 ns Secret**：不行；在消费 ns 创建**连接 Secret**（endpoint/bucket/key/secret）。

---

# 五、10 分钟日常巡检（你可以每天跑）

```bash
# 节点/资源
kubectl get nodes -o wide
kubectl -n cpemon get pods -o wide
kubectl -n platform get pods -o wide

# 关键服务
kubectl -n cpemon get svc mysql && kubectl -n platform get svc minio

# MySQL 冒烟
APP_PW=$(kubectl -n cpemon get secret mysql-auth -o jsonpath='{.data.mysql-password}' | base64 -d)
kubectl -n cpemon run --rm -it sqlchk --restart=Never --image=mysql:8.4 -- \
  sh -lc 'env MYSQL_PWD='"$APP_PW"' mysql -hmysql -ucpemon -e "SELECT 1;" cpemon'

# 备份结果（今天）
MINIO_ACCESS=$(kubectl -n platform get secret minio-auth -o jsonpath='{.data.root-user}' | base64 -d)
MINIO_SECRET=$(kubectl -n platform get secret minio-auth -o jsonpath='{.data.root-password}' | base64 -d)
kubectl -n platform run --rm -it mcls --restart=Never --image=minio/mc:latest \
  --env=MC_HOST_local="http://$MINIO_ACCESS:$MINIO_SECRET@minio.platform.svc.cluster.local:9000" \
  --command -- sh -lc 'mc ls local/mysql-backup/mysql/$(date +%F)/ || true'
```

---

如果你愿意，我也可以把这份**清单版“口袋书”**整理成一页 Markdown（或再加上你集群的专属变量占位），以后每次新环境直接替换即可。随时继续补漏—we’ve got this 💪

