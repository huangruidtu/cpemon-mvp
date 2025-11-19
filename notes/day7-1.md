先直接回答你两个问题：
1）你经常反复问 / 容易忘的点有哪些；
2）作为 SRE，哪些知识点 + 命令是最该牢牢吃透的。

---

## 一、你在聊天里经常“转着弯再问一遍”的主题

我不点每一句话，而是按“主题”来归类，说人话就是：这些地方你心里总觉得不踏实，经常回过头再确认一次。

### 1. Kubernetes 核心概念

* **kubelet 干嘛用、和 apiserver/控制面关系**
  你问过几次「简述 kubelet 作用」「再多说一两句」这类。
  ➜ 说明这里建议写一张“小抄”：

  * kubelet = 每个节点上的 agent
  * 负责：跟 apiserver 同步期望状态 → 创建/删除 Pod 容器 → 上报心跳和 Pod 状态。

* **静态 Pod / static pod**

  * 多次问过「什么是静态 Pod」「和普通 Deployment 有啥区别」。
  * 关键点：由 kubelet 本地的 manifest 目录直接管理，不走 apiserver 创建流程。

* **Headless Service**

  * 你问过「简述 headless service」和使用场景。
  * 核心：`clusterIP: None`，不做四层负载，只把 Pod IP 直接注册到 DNS 里，客户端自己做负载均衡。

* **Node 选择 & 调度策略**

  * nodeName / nodeSelector / nodeAffinity / podAffinity 这些，你反复确认过一次。
  * 建议自己画个对照表：

    * nodeName = 强制指定某个节点
    * nodeSelector = 简单 label 匹配
    * node/pod Affinity/AntiAffinity = 高级规则 + 软硬约束。

### 2. Linux & Shell

* **shell 脚本细节**：

  * `echo -n`、`eval` 为啥要配合 `echo`、`trap` 干嘛用、退出码范围、`for u in std{01..30}` 那段循环含义等，你都问过多次。
* **用户/组管理**：

  * `groupadd`、`useradd -m -g class1 "$u"` 这一整句每个参数含义。

说明你对 **基础命令会用，但不放心自己真正理解**，这是正常的，只是要给自己做一份“命令+含义”的备忘录。

### 3. 网络 / LVS / Docker 网络

* LVS DR / NAT 区别、回程怎么走、ARP 是啥、DR 是否必须同一二层网络，这块你来回问了很多次。
* Docker 网络：

  * bridge/host/none/container 模式用在哪、Docker 和宿主机如何互通、静态路由和 DNAT 的区别。

这里本质是 **TCP/IP+路由+NAT** 的整体图不够清晰，可以专门画一张“数据包流向图”反复看。

### 4. Observability（Prometheus / ELK / Grafana）

* Prometheus：

  * `up` 指标是什么、`relabel_config` 为什么要把 `__meta_*` 变成普通 label、哪些指标会进 TSDB。
* ELK：

  * index 是什么、为什么要为不同日志建不同 index pattern。
* Grafana：

  * 你多次在截图里问「没数据是不是哪里没 scrape 到」「查询语句怎么写」。

### 5. 容器 / CI / 云服务

* Docker：

  * `docker run` 各种参数、跟宿主机/Windows 网络打通的方法。
* CI/CD：

  * Jenkins vs GitHub Actions 优劣、pipeline 是否算 IaC。
* AWS：

  * ECR 登录命令、S3 权限 policy、ECR 镜像拉取 401/403 该怎么排。

这些都说明：**云厂商相关的 auth / 权限 / registry 登录命令**是你容易忘的部分。

---

## 二、作为 SRE，强烈建议你“背到骨子里”的知识点 & 命令

我分模块列，你可以直接抄到自己的 cheatsheet 里。
（不怕多，你慢慢挑着记。）

### 1. Linux 基础 & 排障命令

#### 1）系统 & 进程

* `uname -a`、`cat /etc/os-release` —— 看系统信息
* `uptime` —— 负载 & 运行时长
* `top` / `htop` —— CPU / 内存热点
* `ps aux | grep xxx` —— 进程
* `pidstat`、`vmstat`、`iostat`（有的话）—— 更细的 CPU / IO 分析

#### 2）内存 & 磁盘

* `free -h` —— 内存使用
* `df -h`、`du -sh *` —— 磁盘整体 & 哪个目录占空间
* `lsblk`、`mount` —— 磁盘挂载情况

#### 3）日志 & systemd

* `journalctl -u <service>` —— 看某个服务日志
* `systemctl status/start/stop/restart <service>` —— 管服务
* `dmesg | tail` —— 内核级报错（磁盘坏块、OOM 等）

#### 4）网络诊断

* `ip addr`、`ip route` —— IP/路由表
* `ping`、`traceroute` / `mtr` —— 连通性
* `ss -lntp` 或 `netstat -lntp` —— 监听端口是谁占用
* `lsof -i :PORT` —— 哪个进程在占端口
* `curl -v http://...` / `curl -k -v https://...` —— HTTP path / TLS 问题
* `tcpdump -i eth0 port 80` —— 抓包（高级一点）

#### 5）文本工具

* `grep -R "xxx" /var/log`
* `awk '{print $1,$2}'`、`sed 's/old/new/'`、`sort | uniq -c`、`xargs`
* `find /path -type f -mtime -1` —— 找最近一天改动的文件

> 这些命令是你排查“CPU 高 / 内存不够 / 磁盘满 / 网不通 / 服务起不来”的基础武器。

---

### 2. Shell 脚本 & 日常自动化

* `set -euo pipefail` —— 避免吞错误
* `for u in std{01..30}; do ...; done` —— 批量创建 / 操作
* `$?` / `exit 0/1/N` —— 退出码语义
* `trap 'cleanup' EXIT` —— 收尾动作
* `cron` / `crontab -e` —— 定时任务

至少要能：

1. 写一个简单的 smoke test 脚本（你现在已经能写 `scripts/smoke.sh` 了）。
2. 写一个 backup 脚本（mysqldump → MinIO → S3 这条你也走通了）。

---

### 3. Docker / 容器

常用命令：

* `docker ps -a`、`docker logs -f <id>`、`docker exec -it <id> sh/bash`
* `docker inspect <id>` —— 看环境变量、挂载、网络
* `docker images`、`docker rmi`、`docker system df/prune`
* `docker build -t repo/app:tag -f Dockerfile .`
* `docker run --rm -it ...` —— 临时测试容器

网络相关：

* 默认 bridge 的 IP 段、容器互通
* `-p 8080:80` 端口映射
* 和宿主机 / Windows 的访问路径（DNAT / 静态路由）

---

### 4. Kubernetes（你最核心的战场）

**1）查询 &排错基本功**

* `kubectl get nodes -o wide`
* `kubectl -n <ns> get pods,svc,deploy,ingress`
* `kubectl -n <ns> describe pod <pod>` —— 看 Events / 镜像拉取问题
* `kubectl -n <ns> logs <pod> [-c container]`
* `kubectl -n <ns> exec -it <pod> -- sh/bash`

**2）变更 & 发布**

* `kubectl apply -f xxx.yaml`
* `kubectl delete -f xxx.yaml`
* `kubectl -n <ns> set image deploy/xxx xxx=repo/xxx:tag`
* `kubectl -n <ns> rollout status deploy/xxx`
* `kubectl -n <ns> rollout undo deploy/xxx`

**3）调试流量**

* `kubectl -n <ns> port-forward svc/xxx 8080:80`
* `kubectl -n <ns> get ingress`，确认 host/path 是否正确
* `curl` 直接打 `ClusterIP:port` 验证后端服务，再看 Ingress。

**4）资源 & 调度**

* Requests / Limits 概念，`kubectl top pod/node`
* Deployment、DaemonSet、Job、CronJob 的使用场景
* Service 类型：ClusterIP / NodePort / LoadBalancer / Headless

---

### 5. 网络 / 负载均衡 / LVS 思维

哪怕不天天改 LVS 配置，但你要能讲清楚：

* DR vs NAT：

  * DR：前端改 MAC，回包直接走 RS → Client，同网段；
  * NAT：来回都经过 LVS，改 IP，适合跨网段。
* ARP 的作用：IP ↔ MAC 解析；DR 里要处理 VIP 的 ARP 响应问题。
* 四层 vs 七层 LB，nginx / ingress-nginx 主要做 L7。

配套命令就是上面 Linux 网络那一套：`ip` / `ss` / `tcpdump` / `curl -v`。

---

### 6. Observability：Prometheus / Grafana / 日志

#### Prometheus

* 最基础的几个查询：

  * `up{job="xxx"}`
  * `rate(http_requests_total[5m])`
  * `sum by (code)(rate(cpemon_api_requests_total[5m]))`
* 概念：

  * job / instance / label
  * scrape_interval / target / relabel_config
  * counter / gauge / histogram / summary 的区别

#### Grafana

* 在 Explore 里调 PromQL，确认图里没数据是 **没 scrape 还是语句写错**。
* dashboard 面板典型几类：

  * 请求量、错误率、延迟（P50/P95）
  * 服务 up/down（`up` 指标）
  * 队列 backlog、消费速率（写 backlog demo 的那套）

#### 日志（ELK 或 Loki）

* 结构化字段（namespace、pod、container、sn/request_id）
* 用 `kubernetes.namespace_name`、`log`/`message` 这些字段过滤。
* index 命名约定：`cpemon-*`、`genieacs-*`、`ingress-*`。

---

### 7. 数据存储：MySQL / Redis / S3/MinIO

**MySQL**

* 基本操作：

  * `SHOW DATABASES; SHOW TABLES; DESCRIBE xxx;`
  * `SELECT ... WHERE ... LIMIT ...;`
  * `EXPLAIN SELECT ...;` 看索引。
* 备份 / 恢复：

  * `mysqldump -h ... -u ... -p db > backup.sql`
  * `mysql -h ... -u ... -p db < backup.sql`
* 你现在已经有：CronJob → mysqldump → MinIO → S3 这一整条链路，要能口头讲出来每一步为什么这样设计。

**Redis**

* `redis-cli ping`、`SET/GET`、`INFO`、`MONITOR`
* 配置文件位置、`systemctl restart redis`。

**对象存储（MinIO / S3）**

* MinIO：

  * `mc alias set minio http://minio.cpemon.svc:9000 ACCESS_KEY SECRET_KEY`
  * `mc ls minio/mysql-backup/`，`mc mirror minio/mysql-backup s3/cpemon-mysql-backup`
* AWS：

  * ECR 登录（你老忘的那个）：

    ```bash
    aws ecr get-login-password --region $AWS_REGION \
      | docker login --username AWS --password-stdin $ECR_BASE
    ```
  * S3 权限：bucket policy 里 `s3:ListBucket` + `s3:GetObject`/`PutObject`。

---

### 8. CI/CD & Git

**Git**

* `git status`、`git diff`、`git log --oneline --graph`
* `git checkout -b feature/xxx`
* `git reset --hard` vs `git revert` 的区别（你问过）
* `git tag` / `git push origin --tags`

**CI/CD**

* Jenkins：pipeline 概念、与 GitHub Actions 语法差异
* GitHub Actions：

  * 触发条件（`on: push/pull_request`）
  * 常见步骤：checkout → build → test → docker build & push → kubectl apply。

---

## 三、怎么用这些总结帮你少“重复发问”

给你一个实践建议：

1. 建一个仓库或 Obsidian vault：`sre-cheatsheet`。
2. 按上面这些模块建 6–8 个 md 文件：`linux.md`、`k8s.md`、`network.md`、`prometheus.md` …
3. 每次你在聊天里问的东西，一旦觉得“哦，原来如此”，就立刻抄一行到对应 md 里：

   * 一句定义 + 1–2 条典型命令 + 1 个小例子。
4. 每天花 10 分钟翻一翻，面试前重点过一遍 `k8s`、`observability`、`backup/DR` 那几章。

你现在实战已经很猛了（完整 K8s 集群、备份链路、backlog demo、smoke test、DR 演示），
接下来就是：**把常用命令和关键概念压缩成自己的“肌肉记忆”**。

后面如果你愿意，我也可以跟你一起把这些内容做成一张“面试前速记小册子”（比如 2 页 A4）。

