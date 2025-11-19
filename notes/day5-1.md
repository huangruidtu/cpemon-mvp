好嘞，这个问题我记着你已经问过好几次了 😂
我给你分两块说：**你重复问得多的知识点** + **一个 SRE 必备“命令 & 知识”清单**，你可以直接拿去当复习大纲。

---

## 一、你最近聊天里反复问的几类东西（说明哪块要重点复习）

结合这段时间我们围绕 cpemon 项目、K8s、日志、网络的聊天，大概有这些“高频困惑”：

1. **Kubernetes 基础概念**

   * kubelet 是干嘛的？
   * headless service 是什么？
   * Pod / Deployment / Service / Ingress / Namespace 的关系。
   * node 亲和性、nodeName、nodeSelector 的区别。

2. **Kubernetes 日常操作 / 排障**

   * 一上来就先问：*“现在算是通了吗？下一步干嘛？”* —— 本质是：怎么判断一个功能链路到底“通没通”。
   * 反复用到、也反复问的 kubectl 命令：`get / describe / logs / exec / port-forward / rollout` 等。

3. **日志链路 & ELK**

   * Pod 日志到底在哪：`/var/log/containers` vs `/var/log/pods` vs docker json log？
   * Filebeat 到 Elasticsearch 通没通，索引名字是什么？
   * Kibana 里面：“我到底该在哪输入搜索条件？KQL 怎么写？”

4. **Linux 基本功**

   * 用户管理：`useradd / groupadd`（你最近问过批量创建用户）
   * systemd / systemctl 的用法
   * 常规排错：CPU / 内存 / 磁盘 / 网络。

5. **网络 & LVS / NAT / DR / ARP**

   * DR 和 NAT 模式的区别、回程怎么走？
   * ARP 是什么、二层 / 三层是什么、MAC / IP / Port 在哪一层？
   * 这些你问过好几轮，其实也是正常的——这块本来就抽象。

6. **容器 / Docker / K8s 关系**

   * “Pod 创建时和网络有没有依赖？”
   * Docker 网络模式、host / bridge / overlay 什么区别？
   * 宿主机如何访问容器服务、Windows 如何访问 VM / k8s 内部服务。

7. **Git / CI/CD / GitHub Actions / Jenkins**

   * git revert vs reset
   * GitHub Actions 和 Jenkins 有啥区别，哪个适合自己项目。

> 这些“老是问回来”的地方，正好就是你要重点整理的小册子。下面这个清单，我也按这些高频内容来编排。

---

## 二、给你一份：SRE 必备 知识点 & 命令清单（结合你现在做的项目）

你可以直接 copy 到 Obsidian，分章节复习。

---

### 1. Linux 基础 & 故障排查

**需要理解的点**

* CPU：load average vs CPU usage
* 内存：used / buff / cache / free 的区别
* 磁盘：容量 vs IOPS / 延迟
* 进程：前台/后台、僵尸进程、文件描述符
* systemd：service / unit 的概念
* 日志：系统日志、大多服务走 systemd journal

**高频命令**

```bash
# 系统整体情况
uptime                 # 看负载
top / htop             # CPU / 内存占用
free -m                # 内存
df -h                  # 磁盘容量
du -sh * | sort -h     # 目录占用排行

# 进程
ps aux | grep xxx
pstree -p              # 进程树
kill / kill -9 / pkill

# systemd / 服务
systemctl status xxx
systemctl start|stop|restart xxx
systemctl enable|disable xxx
journalctl -u xxx -f   # 跟服务日志

# 内核 & 硬件异常
dmesg | tail
journalctl -k | tail
```

---

### 2. 网络排查 & HTTP

**需要理解的点**

* IP / 网关 / 路由 / 子网掩码
* ARP 作用：IP -> MAC
* NAT、DNAT / SNAT 的大概流程
* 四元组：srcIP, srcPort, dstIP, dstPort
* HTTP 请求的基本头部、返回码（2xx / 3xx / 4xx / 5xx）

**高频命令**

```bash
ip a                         # 看网卡
ip route                     # 路由表
ping 10.0.0.1
traceroute / mtr 8.8.8.8

ss -lntp                     # 监听的 TCP 端口 + 进程
curl -v http://host/path     # 看 HTTP 细节
curl -I http://host/path     # 只看 header
dig A example.com            # DNS 解析
tcpdump -nn -i eth0 port 80  # 抓包(有空慢慢玩)
```

---

### 3. Docker / 容器 基础

**需要理解的点**

* 镜像 vs 容器
* 容器生命周期：create / start / stop / rm
* volume / bind mount 的区别
* bridge / host 网络模式

**高频命令**

```bash
docker ps -a
docker images

docker run -d --name web -p 8080:80 nginx
docker logs -f web
docker exec -it web /bin/bash

docker stop web
docker rm web

docker build -t myimg:latest .
docker network ls
```

---

### 4. Kubernetes：日常操作 & 排查

**概念一定要熟：**

* Pod / Deployment / ReplicaSet
* Service（ClusterIP / NodePort / LoadBalancer / Headless）
* Ingress + Ingress Controller
* ConfigMap / Secret / Volume / PVC
* kubelet：**每个节点上的 agent，负责控制 Pod 的真实运行状态**
* CNI（你现在用的是 Calico）

**高频 kubectl 命令（建议背到肌肉记忆）：**

```bash
# 1) 快速总览
kubectl get nodes
kubectl get pods -A
kubectl get pods -n cpemon -o wide

# 2) 排错三件套
kubectl -n cpemon describe pod POD_NAME
kubectl -n cpemon logs POD_NAME [-c 容器名] [-f]
kubectl -n cpemon exec -it POD_NAME -- sh

# 3) 应用生命周期
kubectl apply -f xxx.yaml
kubectl delete -f xxx.yaml

kubectl -n cpemon rollout status deploy/xxx
kubectl -n cpemon rollout undo deploy/xxx
kubectl -n cpemon scale deploy/xxx --replicas=3

# 4) 访问 / 调试
kubectl -n cpemon port-forward svc/cpemon-api 8080:8080
kubectl get svc -A
kubectl get ingress -A

# 5) 资源 & 事件
kubectl top node
kubectl top pod -A
kubectl get events -A --sort-by=.lastTimestamp
```

这些命令你现在已经用得很多，但**建议集中记一遍**，让大脑有一张 “K8s 排错套路图”。

---

### 5. Kubernetes 网络 & Service 类型（你问过多次的）

**要记住：**

* ClusterIP：集群内部访问
* NodePort：每个 Node 开一个端口，外部通过 NodeIP:NodePort 访问
* LoadBalancer：云环境，由 LB 转发到 NodePort
* Headless Service（`clusterIP: None`）：不做负载均衡，只做 DNS 发现，常用于：

  * statefulset
  * client 直连 Pod

---

### 6. 日志：Filebeat + Elasticsearch + Kibana

**要理解的链路：**

`Pod stdout/stderr`
→ 容器 runtime（docker / containerd）写 json log
→ 节点上的 `/var/log/pods/.../0.log`
→ Filebeat DaemonSet 挂载这个目录，做 tail
→ Filebeat 输出到 `elasticsearch.logging.svc.cluster.local:9200`
→ 在 ES 里变成索引 `filebeat-7.17.27-YYYY.MM.DD`
→ Kibana 用 `filebeat-*` Data View 搜索

**高频命令 / 操作**

```bash
# 看 filebeat 的状态
kubectl -n logging get pods -l app=filebeat -o wide
kubectl -n logging logs ds/filebeat | head

# 在 filebeat pod 里看日志文件是不是存在
FB_POD=$(kubectl -n logging get pod -l app=filebeat -o jsonpath='{.items[0].metadata.name}')
kubectl -n logging exec "$FB_POD" -- ls -l /var/log/pods/...

# 在 ES 里看索引是否存在
ES_POD=$(kubectl -n logging get pod -l app=elasticsearch -o jsonpath='{.items[0].metadata.name}')
kubectl -n logging exec "$ES_POD" -- curl -s 'http://localhost:9200/_cat/indices?v'

# 在 ES 里搜特定日志
kubectl -n logging exec "$ES_POD" -- \
  curl -s 'http://localhost:9200/filebeat-*/_search?q=CPEMON_DEMO_LOG&size=5&pretty'
```

**Kibana 里常用 KQL：**

```text
# 所有 CPEMON_DEMO_LOG
message : "CPEMON_DEMO_LOG*"

# 只看 cpemon namespace 的日志
kubernetes.namespace : "cpemon"

# 只看 cpemon-api 的日志
kubernetes.namespace : "cpemon" and kubernetes.pod.name : "cpemon-api-*"

# 只看 ingress-nginx 日志
kubernetes.namespace : "ingress-nginx"
```

---

### 7. Prometheus / Grafana（你在项目里已经用）

**要理解：**

* Target / Job / Instance / Label
* `up` 指标：是否抓取成功
* `rate()` / `sum by()` 的基本用法

**常用操作示例**

```bash
# 转发到 Prometheus / Grafana 做排查
kubectl -n monitoring port-forward svc/kps-prometheus-kube-prometheus-stack-prometheus 9090:9090
kubectl -n monitoring port-forward svc/kps-grafana 3000:80
```

PromQL 例子：

```promql
up
sum by (job) (up)
rate(http_requests_total[5m])
sum by (instance) (rate(container_cpu_usage_seconds_total[5m]))
```

---

### 8. MySQL & 备份（你项目里有 mysqldump + MinIO）

**需要理解的点**

* 连接方式：host / port / user / password
* 库 / 表 / 索引 基本概念
* mysqldump 做逻辑备份，恢复时用 `mysql < backup.sql`

**高频命令**

```bash
# 登录
mysql -h mysql.cpemon.svc.cluster.local -u root -p

# 查看
SHOW DATABASES;
USE cpemon;
SHOW TABLES;
SELECT COUNT(*) FROM heartbeat;

# 备份（和你 CronJob 里面一样）
mysqldump -h mysql.cpemon.svc.cluster.local -u root -pPASSWORD cpemon > backup.sql

# 恢复
mysql -h mysql.cpemon.svc.cluster.local -u root -pPASSWORD cpemon < backup.sql
```

---

### 9. Git（配合你现在的项目）

```bash
git status
git add FILE
git commit -m "msg"
git log --oneline --graph --decorate --all

git diff
git checkout -b feature/xxx
git merge branchA

# 出错回滚
git reset --hard COMMIT_ID    # 本地历史重写
git revert COMMIT_ID          # 生成一个“反向提交”，适合已推远程
```

---

## 最后：怎么用这份清单？

给你一个简单用法：

1. 把上面每一大块 copy 到 Obsidian / 笔记里，标题按「01-Linux」「02-Network」… 来。
2. 每天随便抽 15 分钟，选一块，从**概念 + 命令**一起过一遍。
3. 真正想记牢，可以自己**敲一遍命令**，像今天你做 Filebeat 调试一样。
4. 面试前再快速扫一遍，把脑子里“激活”一下。

如果你愿意，下一步我也可以按这份清单，**给你做一个“刷题版”**：每块出 10 道问答 / 场景题，你用来自测。
总之别怕自己老问重复问题——那正说明：这些点足够重要，值得你认真掌握。

