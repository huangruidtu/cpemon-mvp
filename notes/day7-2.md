我直接上干货哈：先帮你点名“你反复问过的东西”，再给你一份**SRE 核心知识 + 常用命令清单**。你可以当成复习路线图。

---

## 一、这段时间你反复问过 / 卡壳的点

这些基本可以视为你现在的“知识薄弱区 + 必修课”：

1. **Kubernetes 基础概念**

   * kubelet 作用、静态 Pod 是什么；
   * Headless Service 有啥用；
   * nodeSelector / nodeName / node affinity / pod affinity 区别；
   * master 节点也承载业务 Pod 时怎么规划调度。

2. **k8s 运维命令和排障**

   * `kubectl get/describe/logs/exec` 的组合拳；
   * Pod 创建失败 / Ready=False / CrashLoopBackOff 时该看哪里；
   * 证书有效期、kubeadm 集群结构这些也问过好几次。

3. **Docker & 网络**

   * Docker 四种网络模式有什么区别；
   * Docker 容器如何和宿主机 / Windows 联通；
   * 本地 Harbor / 云上镜像仓库的用途和取舍。

4. **LVS / 负载均衡 / 网络回程**

   * LVS DR 模式 vs NAT 模式；
   * 回程流量怎么走、和 MAC / ARP 的关系；
   * iptables SNAT/DNAT 的逻辑。

5. **Prometheus / Consul / Exporter**

   * relabel_config 是干嘛的；
   * `__meta_*` 元数据如何映射成普通标签；
   * `up` 指标为什么有那么多条；
   * blackbox_exporter 用在什么场景。

6. **ELK / 日志**

   * Elasticsearch 的 index 概念；
   * Filebeat 怎么按 namespace / 日志类型区分；
   * Kibana 索引搜索 / index pattern。

7. **MySQL / Redis 基础运维**

   * apt 安装 vs 源码安装的差异；
   * systemd 里 service / alias 是怎么回事（`redis.service` vs `redis-server.service`）；
   * `mysqldump`、备份 / 恢复、连接数、慢查询这些。

8. **Shell 进阶**

   * `trap` 做什么；
   * `-n`、`eval`、自定义退出码；
   * 批量创建用户、for 循环脚本等。

9. **Git / CI/CD**

   * `git revert` vs `reset`；
   * Jenkins pipeline vs freestyle；
   * GitHub Actions 和 Jenkins 特点对比。

10. **SRE 职责 & 怎么讲故事**

    * “SRE 核心职责”这类面试回答；
    * 如何把 MVP-CPEmon 讲出一个完整的架构/运维故事。

这些都是你**多次回来的问题**，基本可以认为：再过几个月，面试官八成也会在这些点上打你。

---

## 二、按模块帮你列一份 SRE 核心知识 + 高频命令清单

> 你可以把这一节当成「长期复习大纲」，不嫌多就全收下。

### 1. Linux 系统基础（必须扎实）

**知识点：**

* 进程 / 内存 / CPU / 磁盘 / 文件系统 / 权限；
* systemd / service 管理；
* 常见日志路径（`/var/log/*`）、journalctl。

**常用命令：**

* 资源 & 状态

  * `uname -a`（系统信息）
  * `uptime`（负载）
  * `top` / `htop`（CPU/内存）
  * `free -h`（内存）
  * `df -h`（磁盘使用）
  * `du -sh *`（当前目录大小分布）
* 进程

  * `ps aux | grep ...`
  * `kill / kill -9`
  * `journalctl -u <service>`
* service / systemd

  * `systemctl status/start/stop/restart <service>`
  * `systemctl enable/disable <service>`
* 用户 & 权限

  * `useradd / userdel / usermod`
  * `groupadd / gpasswd`
  * `chmod / chown / chgrp`
* 日常工具

  * `grep -R`, `awk`, `sed`, `find`, `xargs`
  * `tar czf / tar xzf`
  * `ssh`, `scp`, `rsync`

---

### 2. 网络 / 安全 / 负载均衡

**知识点：**

* IP / 路由 / 子网 / DNS；
* 四层 VS 七层负载均衡；
* iptables SNAT/DNAT，LVS DR/NAT 回程；
* TLS 证书、端口监听。

**常用命令：**

* 网络基本信息

  * `ip addr`, `ip link`, `ip route`
  * `ping`, `traceroute` / `mtr`
  * `ss -lntup`（查看监听端口 & 进程）
* HTTP / DNS

  * `curl -v http(s)://...`
  * `curl -I`（仅看 header）
  * `dig`, `nslookup`
* 防火墙 / LVS（按你课程的内容）

  * `iptables -t nat -L -n -v`
  * `iptables -t filter -L -n -v`
  * `ipvsadm -Ln`（LVS 规则和真实服务器）

---

### 3. Shell 编程 & 自动化

**知识点：**

* bash 变量、数组、for/while、函数；
* 返回码 / `set -euo pipefail`；
* `trap` 捕获信号 & 清理资源；
* 组合多条命令：管道、重定向、`xargs`。

**常见写法：**

* 批量处理：

  ```bash
  for u in std{01..30}; do
    useradd -m -g class1 "$u"
  done
  ```

* 判断 & 退出码：

  ```bash
  if ! some_cmd; then
    echo "failed" >&2
    exit 1
  fi
  ```

* `trap`：

  ```bash
  trap 'echo "cleanup"; rm -f /tmp/foo' EXIT INT TERM
  ```

---

### 4. Git & CI/CD

**知识点：**

* Git 基本操作、分支、回滚（`reset` vs `revert`）；
* GitHub / GitLab / Jenkins / GitHub Actions 各自特点；
* Pipeline as Code（Jenkinsfile / GitHub Actions YAML）。

**常用 Git 命令：**

* 查看 & 提交

  * `git status`, `git diff`
  * `git add`, `git commit`
  * `git log --oneline --graph`
* 回滚

  * `git revert <commit>`（保留历史、安全回滚）
  * `git reset --hard <commit>`（本地丢弃，危险但常用）
* 分支

  * `git branch`, `git checkout -b feature/x`
  * `git merge`, `git rebase`

---

### 5. Docker / 容器基础

**知识点：**

* 镜像 / 容器 / 网络 / Volume；
* Bridge / Host / None / Container 四种网络模式；
* 本地 Harbor vs Docker Hub / ECR 等云仓库；
* `docker-compose` 基本用法。

**常用命令：**

* 容器操作

  * `docker ps -a`
  * `docker run -it --rm ...`
  * `docker exec -it <container> /bin/bash`
  * `docker logs -f <container>`
  * `docker stop / rm`
* 镜像

  * `docker images`
  * `docker build -t name:tag .`
  * `docker tag`, `docker push`
* 网络 / 存储

  * `docker network ls / inspect`
  * `docker volume ls / inspect`

---

### 6. Kubernetes（你最核心的盘子）

**知识点：**

* 组件：kube-apiserver / etcd / controller-manager / scheduler / **kubelet** / kube-proxy / CNI；
* 抽象：Namespace / Pod / Deployment / ReplicaSet / Service / Ingress / ConfigMap / Secret / PVC / StatefulSet / CronJob；
* Service 类型：ClusterIP / NodePort / LoadBalancer / **Headless (clusterIP: None)**；
* 调度：nodeSelector / nodeName / nodeAffinity / podAffinity / podAntiAffinity / taints & tolerations；
* 基础网络：Pod CIDR / Service CIDR / CNI（Calico / Flannel）；
* 证书有效期、kubeadm 基础操作。

**高频 `kubectl` 命令：**

* 查看

  * `kubectl get pods -A`
  * `kubectl get pods,svc,deploy,ingress -n <ns>`
  * `kubectl describe pod/deploy/...`
  * `kubectl get events -n <ns>`
* 调试

  * `kubectl logs <pod> [-c <container>] -n <ns>`
  * `kubectl exec -it <pod> -n <ns> -- /bin/sh`
  * `kubectl port-forward <pod/deploy> 8080:80 -n <ns>`
* 管理

  * `kubectl apply -f xxx.yaml`
  * `kubectl delete -f xxx.yaml`
  * `kubectl scale deploy <name> --replicas=3 -n <ns>`
  * `kubectl rollout restart deploy/<name> -n <ns>`
  * `kubectl top pod/node -n <ns>`（配合 metrics-server）

---

### 7. Observability：Prometheus / Grafana / ELK

**Prometheus & Grafana：**

* 知识点：

  * 指标三要素：`<metric_name>{labels} value`；
  * `up` 指标的含义；
  * `rate()`, `irate()`, `sum by (...)` 等基础 PromQL；
  * `relabel_configs` 把 `__meta_*` 变成普通标签；
  * Node exporter、blackbox exporter、服务自身的 `/metrics`。

* 常用动作：

  * 看 `up{job="xxx"}` 确认抓没抓到；
  * 看 HTTP 请求指标：`http_requests_total`;
  * 检查 scrape config 中的 relabel 是否把 namespace/pod 转成 label。

**Elasticsearch / Kibana / Filebeat：**

* 知识点：

  * index / shard / replica；
  * Filebeat 从 K8s Pod 日志收集；
  * Kibana 按 `kubernetes.namespace`, `kubernetes.pod.name`, CPE SN 搜索；
  * 日志保留策略 vs 磁盘空间。

* 实用 API / 命令（你已经在 runbook 里用上了）：

  * `_cluster/health` 看健康；
  * `_cat/indices` 看索引大小；
  * 删除旧索引释放磁盘。

---

### 8. 数据库 & 缓存（MySQL / Redis）

**MySQL：**

* 知识点：

  * 基本 CRUD，索引概念；
  * 连接数 / `max_connections`；
  * 事务简单概念；
  * 备份恢复（`mysqldump` + MinIO / S3）；
  * 性能 & 慢查询。

* 常用命令：

  ```sql
  SHOW DATABASES;
  USE cpemon;
  SHOW TABLES;
  DESCRIBE some_table;
  SELECT * FROM some_table LIMIT 10;

  SHOW VARIABLES LIKE 'max_connections';
  SHOW GLOBAL STATUS LIKE 'Threads_connected';
  SHOW FULL PROCESSLIST;
  ```

  * Shell 侧：

  ```bash
  kubectl -n cpemon exec -it deploy/mysql -- mysql -uroot -p
  mysqldump -u... -p... dbname > backup.sql
  ```

**Redis：**

* 知识点：

  * 配置文件路径（例如 `/etc/redis/redis.conf`）；
  * systemd service 名（`redis-server.service` / `redis.service` 的 alias）；
  * 基本命令：`GET` / `SET` / `EXPIRE` / `DEL`；
  * 持久化（RDB / AOF）是个加分项。

---

### 9. 消息队列 / Kafka（在你项目里是“没上但会讲”的技能）

**知识点：**

* Topic / Partition / Consumer Group；
* 至少一次 / 最多一次 / 恰好一次；
* 死信队列 / 重试队列思路；
* 在 cpemon 场景里，**会讲清楚“如果以后要上 Kafka，我会放在哪个环节”** 就够了。

**基本 CLI 命令：**

* `kafka-topics.sh --create/--list/--describe`
* `kafka-console-producer.sh` / `kafka-console-consumer.sh`

---

### 10. 备份 & 灾备（Backup / DR）

你在项目里已经用到：

* Velero（在 `backup` namespace）；
* MinIO（在 `platform` namespace，作 S3 兼容存储）；
* MySQL CronJob 备份。

**知识点：**

* 备份范围：只备 etcd？只备某个 namespace？还是包括存储卷；
* RPO/RTO 概念；
* 恢复演练（你现在有 `backup_restore.sh` 这个就很加分）。

---

## 三、给你一个“可以打印出来贴墙上”的小建议

如果你想实战复习，可以这样用这份清单：

1. 挑 **2–3 个模块**（比如 Linux + Kubernetes + Observability），
   给自己定目标：“这一周把这些命令都在我的集群 / VM 上操作一遍”。

2. 每个命令不要只看，要**带着问题去执行**：

   * `kubectl get pods -A` → 找出不正常的 Pod；
   * `df -h` → 找出谁占用最多盘；
   * `SHOW FULL PROCESSLIST;` → 找出谁在 MySQL 里卡着不走。

3. 凡是你在这次对话中**问了两遍以上的概念**，都在笔记里单开一页，总结成“我自己能讲出来”的版本。

---

如果你愿意，下一步我可以帮你把这些拆成一个**30 天 SRE 复习计划**，每天就练一两块，最后刚好对齐你现在这个 CPEmon 项目，面试时能做到“嘴上说得清楚、手上敲得出来”。

