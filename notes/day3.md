我直接给你三部分：

1. **你在这一路项目里反复问到的点（= 你的“薄弱环节清单”）**
2. **按 SRE 能力图谱，帮你整理要掌握的知识块**
3. **一份“常用命令清单”，分模块列出来（可当你的复习 checklist）**

你可以拿这个当“长期复习纲要”。

---

## 一、你反复问到 / 卡住过的主题（重点复习清单）

我不按时间，而是按主题整理，你自己肯定能对上号：

### 1. K8s 网络 & 访问方式

你经常会在这些地方反复卡住：

* **为什么 `127.0.0.1:3306` 不行，但 `Service ClusterIP:3306` 行？**
* 在 host 上访问集群里的服务：`kubectl port-forward` 怎么用、需要不需要先装 `socat`。
* Service / Pod / NodeIP / ClusterIP 的区别：

  * Pod IP 只能在集群里用；
  * Service IP 是稳定入口；
  * NodePort / Ingress 再往外暴露。
* 经常要我帮你看：

  * `kubectl get svc/ep -n cpemon`
  * `mysql` 到底是 Pod IP 还是 Service 名（`mysql.cpemon.svc.cluster.local`）。

👉 这类问题说明：
**“从本机 → K8s 内部服务”这条路径要重点吃透：`port-forward`、Service DNS、iptables 转发。**

---

### 2. 容器镜像 / CI / Registry（本地 Docker vs GitHub Actions vs ECR）

反复问过、一起 debug 过的点：

* 本地 `docker build -t cpemon-api:test` 成功了，但：

  * ECR 里看不到镜像；
  * GitHub Actions workflow 只 build/test，不 push；
  * 需要单独写 `docker-ecr.yml`。
* ECR 里出现了 tag：

  * `latest` + 一串 SHA；你会问“这个随机数是啥？”（其实是 commit SHA）。
* K8s Deployment 里用的 `image:`

  * 一会儿是本地 tag，
  * 一会儿是 ECR URI，
  * 经常要我明确写完整 `7015...dkr.ecr.../cpemon-api:latest` 给你。

👉 这里的“反复点”：
**镜像从“源码 → CI → ECR → K8s Deployment”的整条链路，要形成清晰的 mental model。**

---

### 3. K8s 清单 & 目录结构

你好几次问：

* YAML 应该放 `app/` 还是 `k8s/app/`？
* 源码、Dockerfile、K8s YAML 的合理目录结构是啥样？
* 需要我给你完整的 YAML 路径，避免你“改错文件”。

👉 说明你**已经有感觉“结构化很重要”**，但目前还没形成自己的固定套路。
这个可以靠：

* 多看几个优秀 repo 的 layout；
* 固定采用 `app/`（源码）+ `k8s/`（部署）+ `cicd/`（workflow）的结构。

---

### 4. MySQL 连接 / 密码 / Secret

卡过几次的点：

* 忘记 root 密码，只能从 `Secret mysql-auth` 里 base64 解。
* `mysql -h127.0.0.1 -P3306` 连不上，其实 MySQL 在 Pod 里；
  后来改成 `-h <ClusterIP>` 才成功。
* DSN 里 host 填 `127.0.0.1` vs `mysql.cpemon.svc.cluster.local` 的区别。

👉 重点是：
**区分“虚机里的 MySQL”与“K8s 里的 MySQL Service”**，以及用 Secret 驱动配置。

---

### 5. port-forward / 工具依赖

今天典型一幕：

* `curl localhost:8080/healthz` 一直 “Empty reply”，
* Pod 日志却显示 readiness probe 200 没问题；
* 最后发现是 `kubectl port-forward` 在 node 上缺 `socat`。

👉 这类问题，实际上是在考**你对“kubectl 这个 CLI 本身的行为”的理解**，
尤其是 `port-forward` / `logs` / `exec` 的原理。

---

### 6. 之前课程里你多次问过的知识点（从长周期看）

从你别的会话记录里，我看到你经常反复问这些：

* Linux：

  * `groupadd` / `useradd` / UID/GID；
  * systemd / `systemctl` / `journalctl`；
  * 分区、fstab、开机流程。
* Shell & 脚本：

  * `echo -n` 是啥；
  * `trap` 干嘛用；
  * 自定义退出码；
  * `eval` 为啥后面加 `echo`。
* 网络 & LVS：

  * DR 与 NAT 模式的区别；
  * ARP、MAC、回程流量；
  * 静态路由 / iptables / Docker 网络模式。
* K8s 概念：

  * kubelet 的作用、静态 Pod；
  * headless service；
  * nodeSelector / affinity / anti-affinity；
  * master 也承载业务 Pod 的调度策略。

👉 这些“反复刷”的，其实已经非常典型地覆盖了一个 SRE 的**核心基础面**。

---

## 二、按 SRE 能力图谱帮你捋一遍“必须掌握的知识块”

我给你一个**“中级 SRE 能力树”**，你可以对照自己哪些已经 OK、哪些要重点复习。

### 1. Linux / OS 基础

* **进程 & 服务：**

  * systemd：`systemctl status/start/stop/restart`；
  * 查看进程：`ps aux`, `top/htop`, `pidstat`；
  * CPU/内存/负载：`uptime`, `dmesg`, `free -h`, `vmstat`, `iostat`。
* **日志：**

  * `journalctl -u xxx.service -f`；
  * 应用自带 log（nginx、mysql、kubelet 等）。
* **文件系统 & 磁盘：**

  * `df -h`, `du -sh`, `lsblk`, `mount`, `fstab` 基本概念；
  * inode、软硬链接、权限位（`chmod/chown`）。
* **用户与权限：**

  * `useradd`, `groupadd`, `id`, `sudo` 配置；
  * 不登录用户（`/usr/sbin/nologin`）为什么存在。

---

### 2. Shell & 日常工具

* bash 语法：变量、条件、循环、函数、退出码。
* 常用命令：

  * 文本处理：`grep`, `sed`, `awk`, `cut`, `tr`, `sort`, `uniq`, `wc`；
  * 文件：`find`, `xargs`, `tee`, `head`, `tail`, `less`；
  * JSON：`jq`；
  * 时间：`date`。
* 脚本规范：

  * `set -euo pipefail`；
  * 使用函数 + 清晰日志；
  * 正确处理 `$?` 和自定义退出码。

---

### 3. 网络 & 负载均衡

* OS 网络命令：

  * `ip addr`, `ip route`, `ip link`, `ip neigh`；
  * `ss -tulpn`（听端口），`nc`, `telnet` 做连通性测试；
  * DNS：`dig`, `nslookup`。
* 基础概念：

  * TCP 三次握手、端口、四元组；
  * NAT / SNAT / DNAT；
  * 路由表、静态路由、网关。
* 负载均衡：

  * LVS DR vs NAT 的区别、回程路径问题；
  * L4 vs L7；
  * Nginx / HAProxy 的反向代理、健康检查。

---

### 4. Docker / 容器

* 概念：

  * 镜像 / 容器 / Registry；
  * 镜像分层、tag、digest。
* 常用命令：

  * `docker ps -a`, `docker logs`, `docker exec -it`, `docker run -p`, `docker rm`, `docker stop`；
  * `docker images`, `docker rmi`, `docker pull`, `docker tag`, `docker push`；
  * `docker inspect` 看 IP / env / 挂载。
* 网络模式：

  * bridge / host / none / container；
  * 本机访问容器服务：`-p 8080:80` vs iptables DNAT。

---

### 5. Kubernetes（重头戏）

* **操作习惯：**

  * `kubectl config get-contexts`, `use-context`；
  * 永远带 `-n`；
  * `-o wide`, `-o yaml`, `-l app=xxx`。
* **排查三板斧：**

  1. `kubectl get`（pods, svc, ep, ingress, events）
  2. `kubectl describe`（pod/deploy/svc）
  3. `kubectl logs` + `kubectl exec`。
* **常用命令：**

  * `kubectl get pods -o wide`
  * `kubectl logs pod -f`
  * `kubectl exec -it pod -- bash`
  * `kubectl apply -f` / `kubectl delete -f`
  * `kubectl rollout restart deploy/xxx`
  * `kubectl rollout status deploy/xxx`
  * `kubectl scale deploy/xxx --replicas=N`
  * `kubectl get events --sort-by=.lastTimestamp`
  * `kubectl port-forward svc/xxx 8080:80`
  * `kubectl top pods/nodes`（配合 metrics-server）。
* **核心资源理解：**

  * Pod / Deployment / ReplicaSet / StatefulSet；
  * Service（ClusterIP/NodePort/LoadBalancer/Headless）；
  * Ingress（+ ingress-nginx）；
  * ConfigMap / Secret / PVC；
  * PDB / HPA / Affinity / Toleration / nodeSelector。
* kubelet / 静态 Pod / CNI（calico/flannel）的基本概念。

---

### 6. 数据库 & 存储（MySQL 为例）

* 常见操作：

  * 登录：`mysql -h host -P port -u user -p`；
  * `SHOW DATABASES;`, `USE db;`, `SHOW TABLES;`；
  * `DESCRIBE table;` / `EXPLAIN SELECT ...;`。
* 性能与排障：

  * 慢查询日志（slow log）；
  * 连接数、innodb buffer、索引；
  * 基本备份（mysqldump）、恢复流程。
* 在 K8s 中：

  * Service 名作为 host；
  * DSN 里用 `user:pass@tcp(mysql.namespace.svc.cluster.local:3306)/db?parseTime=true`。

---

### 7. Observability（Prometheus / Grafana / ELK）

* Prometheus：

  * `up` 指标含义；
  * Target / scrape / relabel_config；
  * 常见 PromQL：`rate`, `sum by`, `avg_over_time` 等。
* Grafana：

  * 配置 DataSource；
  * 导入 dashboard；
  * 会自己写 2–3 个简单图（CPU/Mem、请求量、错误率）。
* 日志（ELK / Loki）：

  * 索引 / Index pattern 的概念；
  * Kibana 里按 `namespace`, `pod`, `sn`, `request_id` 等过滤；
  * 会从日志中快速找到某条请求的全链路。

---

### 8. CI/CD & Git

* Git：

  * `status`, `diff`, `log`, `branch`, `checkout`, `commit`, `push`, `pull`；
  * 回滚：`revert`, `reset --hard`, `tag`。
* CI（GitHub Actions / Jenkins）：

  * 会看懂一个简单 pipeline：checkout → build → test → build docker → push；
  * 理解 secrets / environment / matrix / cache 的用法。
* CD：

  * 对你这个项目来说，至少要能：

    * 看懂“Git push → 镜像更新 → K8s rolling update”的流程；
    * 手动执行 `kubectl apply` / `rollout restart` 完成一次部署。

---

### 9. 云基础（以 AWS 为例）

* IAM：

  * User / Role / Policy；
  * Access key / Secret key 的用途和危险性；
* 基本服务：

  * ECR：私有镜像仓库；
  * S3：对象存储；
    -（将来可能还有 EC2 / RDS / ALB）。
* CLI：

  * `aws configure`；
  * `aws sts get-caller-identity`；
  * `aws ecr describe-repositories` / `get-login-password`。

---

## 三、按模块给你一份“命令速查清单”（可以当 checklist 背）

我给你一份稍微精简版的，都是你在项目里已经用过 / 将会高频用的。

### 1. Linux & Shell

```bash
# 进程 & 服务
ps aux | grep xxx
top / htop
systemctl status xxx
systemctl restart xxx
journalctl -u xxx.service -f

# 磁盘 & 文件
df -h
du -sh *
lsblk
find . -name 'xxx*'

# 用户
id
useradd -m -g group user
groupadd class1

# 网络
ip addr
ip route
ss -tulpn
curl -v http://host:port/path
dig domain.com
ping / traceroute

# 文本处理
grep -i "error" file.log
tail -f file.log
sed 's/foo/bar/g' file
awk '{print $1,$2}' file
```

---

### 2. Docker

```bash
docker ps -a
docker logs -f <container>
docker exec -it <container> /bin/bash

docker build -t myapp:test -f docker/Dockerfile .
docker images
docker tag myapp:test 7015....dkr.ecr.eu-north-1.amazonaws.com/myapp:latest
docker push 7015....dkr.ecr.eu-north-1.amazonaws.com/myapp:latest
```

---

### 3. Kubernetes（你最该熟练的一组）

```bash
# 基本资源 & 排查
kubectl get nodes
kubectl get pods -n cpemon -o wide
kubectl get svc -n cpemon
kubectl get endpoints -n cpemon
kubectl get ingress -n cpemon
kubectl get events -n cpemon --sort-by=.lastTimestamp

kubectl describe pod <pod-name> -n cpemon
kubectl logs <pod-name> -n cpemon
kubectl logs deploy/cpemon-api -n cpemon

kubectl exec -it <pod-name> -n cpemon -- /bin/sh

# 部署 & 发布
kubectl apply -f k8s/app/cpemon-api.yaml
kubectl delete -f k8s/app/cpemon-api.yaml

kubectl rollout restart deploy/cpemon-api -n cpemon
kubectl rollout status deploy/cpemon-api -n cpemon

kubectl scale deploy/cpemon-api -n cpemon --replicas=2

# 端口转发（你刚刚已经体会很深了）
kubectl -n cpemon port-forward svc/cpemon-api 8080:8080
kubectl -n cpemon port-forward svc/cpemon-writer 8082:8080
```

---

### 4. MySQL

```bash
mysql -h mysql.cpemon.svc.cluster.local -P3306 -ucpemon -p
SHOW DATABASES;
USE cpemon;
SHOW TABLES;
DESCRIBE cpe_status;
SELECT * FROM cpe_status WHERE sn = 'CPE123'\G;
```

---

### 5. AWS / ECR

```bash
aws configure
aws sts get-caller-identity

AWS_REGION=eu-north-1
AWS_ACCOUNT_ID=701573843911
ECR_REGISTRY="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"

aws ecr describe-repositories --region "$AWS_REGION"
aws ecr get-login-password --region "$AWS_REGION"

kubectl -n cpemon create secret docker-registry cpemon-ecr-regcred \
  --docker-server="$ECR_REGISTRY" \
  --docker-username=AWS \
  --docker-password="$(aws ecr get-login-password --region "$AWS_REGION")"
```

---

如果你愿意，我们可以接下来做一件事：
**把这些知识点 + 命令做成一个你自己的 `SRE-knowledge.md` / `SRE-cheatsheet.md` 放进仓库**，
以后每次做项目 / 复习，就按这个清单扫一遍，把“反复问过”的地方一个个变成肌肉记忆 💪

