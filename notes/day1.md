太好了，来把今天到现在为止**高频“重复问”主题**和**SRE必备知识+命令清单**一次性梳理好。你可以把整答复制到仓库的 `docs/cheatsheets/sre-day1.md`，以后遇到同类问题就按图索骥。

---

# 一、你在这段时间里最常重复问到的主题（含记忆锚点 & 常用命令）

1. **K8s 基础角色（kubelet/静态 Pod/Headless Service）**

   * 记忆锚点：kubelet=每个节点的“Pod 管家”；静态 Pod=由 kubelet 本地清单直接拉起；Headless Service=无 VIP、用于直连 Pod（SRV/EndpointSlice）。
   * 命令：`systemctl status kubelet`、`kubectl get pods -A -o wide`、`kubectl get svc -o wide`。

2. **Service 类型与裸金属 LB（NodePort vs LoadBalancer vs MetalLB）**

   * 锚点：物理机集群无云厂商 LB，就用 **MetalLB** 给 `LoadBalancer` 分配 **EXTERNAL-IP**。
   * 命令：`kubectl -n metallb-system get ipaddresspools,l2advertisements`、`kubectl -n ingress-nginx get svc`.

3. **Ingress-NGINX 两种部署姿势**（你问过很多次 & 切换过）

   * 锚点：

     * **DaemonSet+hostNetwork**：更贴近边缘/低延迟；但与 Helm 所有权容易冲突，网络端口占用敏感。
     * **Deployment+Service(type=LoadBalancer)**：主流、容易运维、配 MetalLB 即可。
   * 命令：`kubectl -n ingress-nginx get deploy,ds,svc,pods -o wide`。

4. **Helm3 用法 & 所有权冲突**

   * 锚点：`helm upgrade --install` 是“幂等装”；已有手工资源会触发“ownership labels/annotations 缺失”的冲突 → **删遗留**再装。
   * 命令：`helm repo add|update`、`helm ls -A`、`helm status <rel> -n <ns>`、`helm get manifest <rel> -n <ns>`。

5. **Calico / Pod 网段**

   * 锚点：`PodCIDR` 来自 CNI（Calico IPPool）；跟宿主机网段隔离。冲突会导致 CNI 起不来。
   * 命令：`kubectl get ippool -A`（或 `calicoctl get ippool`）、`kubectl get node -o wide`。

6. **调度：label / taint / (反)亲和**

   * 锚点：给 worker 打 `ingress-worker=true`，让 Ingress Pod 只落到 worker；master 默认有 `NoSchedule`。
   * 命令：`kubectl label node <node> k=v --overwrite`、`kubectl describe node <node>`。

7. **PDB（PodDisruptionBudget）**

   * 锚点：限制“可被安全驱逐的 Pod 数量”；**minAvailable=1** 防止一次把所有副本赶走。
   * 命令：`kubectl get pdb -A`、`kubectl describe pdb <name> -n <ns>`。

8. **DNS & /etc/hosts & IngressClass**

   * 锚点：开发期用 `/etc/hosts` 绑定 LB IP；IngressClass=控制器选择器（`ingressClassName: nginx`）。
   * 命令：`getent hosts api.local`、`kubectl get ingressclass`、`kubectl -n <ns> describe ingress <name>`。

9. **容器运行时/CRI（docker vs containerd vs cri-dockerd）**

   * 锚点：Kubelet 通过 CRI 与运行时交互；用 docker 时需 **cri-dockerd**；`crictl` 要配 endpoint。
   * 命令：`crictl --runtime-endpoint /var/run/cri-dockerd.sock info`、`docker info --format '{{.CgroupDriver}}'`。

10. **GitHub 连接 & SSH Key**

* 锚点：`git@github.com: Permission denied (publickey)` → 没加公钥或没选对 Key。
* 命令：`ssh-keygen -t ed25519`、`ssh -T git@github.com`、`git remote -v`。

11. **Ingress 规则调试**

* 锚点：404=入口通但无匹配规则；502/504=后端未就绪或 endpoints 为空。
* 命令：`kubectl -n <ns> get endpoints <svc> -o wide`、`kubectl -n ingress-nginx logs deploy/ingress-nginx-controller | tail -n 200`。

12. **Observability（Prom/Grafana/ELK）——你多次问“为什么没看到数据/报警不触发”**

* 锚点：Prom 需要 **ServiceMonitor**；ELK 要 **Index pattern** + Pipeline；报警要 **规则+动作**。
* 命令：`kubectl -n monitoring get servicemonitor`、`curl <svc>/metrics | grep <metric>`、Kibana 的 Discover/Rules。

13. **备份（Velero + S3 / CronJob mysqldump→MinIO）**

* 锚点：Velero 备份 K8s 资源；数据库用 dump；对象存储可 `mc`/`rclone` 镜像到外部。
* 命令：`velero backup create ...`、`kubectl create cronjob ...`、`mc ls|cp|mb`。

14. **Linux/网络基础（你多次反复）**

* 锚点：`hostnamectl`、`systemctl`、`ip/ss/tcpdump`、`iptables`、`route`、`/etc/resolv.conf`。
* 命令：见下方“必备命令表”。

15. **Jira/流程化产物**

* 锚点：任务模板、DoD、冲突复盘、CHANGELOG/Tag；避免“做完就忘”。
* 做法：每个子任务附“目的/命令/验证/产物清单”。

---

# 二、SRE 必备知识与命令清单（优先级从高到低）

> 这是“能救火、能复盘、能上线”的最小闭环。建议直接存成你的**口袋手册**。

## A. 通用排障套路（5 步走）

1. **节点/组件健康**

   ```bash
   kubectl get nodes -o wide
   kubectl -n kube-system get pods -o wide
   kubectl describe node <node> | sed -n '1,120p'
   ```
2. **工作负载链路**（deploy→rs→pod）

   ```bash
   kubectl -n <ns> get deploy,rs,pods -o wide
   kubectl -n <ns> describe deploy <name>
   kubectl -n <ns> logs <pod> --previous -n <ns> --tail 200
   ```
3. **服务发现**（svc→endpoints/EndpointSlice）

   ```bash
   kubectl -n <ns> get svc <svc> -o wide
   kubectl -n <ns> get endpoints <svc> -o wide
   kubectl -n <ns> get endpointslice -l kubernetes.io/service-name=<svc>
   ```
4. **入口（Ingress/Controller）**

   ```bash
   kubectl -n <ns> describe ingress <ing>
   kubectl -n ingress-nginx logs deploy/ingress-nginx-controller | tail -n 200
   ```
5. **事件 & 资源压力**

   ```bash
   kubectl -n <ns> get events --sort-by=.lastTimestamp | tail -n 50
   kubectl top nodes; kubectl -n <ns> top pods
   ```

## B. Kubernetes（日常必须会）

* **滚动发布/回滚**：
  `kubectl -n <ns> rollout status|history|undo deploy/<name>`
* **查错定位**：
  `kubectl -n <ns> describe pod/<name>`、`kubectl -n <ns> logs <pod> -f`
* **资源/YAML 模版**：
  `kubectl create deploy|svc ... --dry-run=client -o yaml`
* **节点调度**：
  `kubectl cordon|uncordon <node>`、`kubectl drain <node> --ignore-daemonsets --delete-emptydir-data`
  `kubectl label node <node> k=v --overwrite`、`kubectl taint nodes <node> k=v:NoSchedule-`

## C. Ingress / MetalLB

* **查看 LB IP & 入口**：
  `kubectl -n ingress-nginx get svc ingress-nginx-controller -o wide`
  `kubectl -n ingress-nginx get ingressclass`
* **常见注解**：
  `nginx.ingress.kubernetes.io/rewrite-target`、`proxy-body-size`、`whitelist-source-range`

## D. Helm（你已大量使用）

```bash
helm repo add <name> <url>; helm repo update
helm upgrade --install <rel> <chart> -n <ns> -f values.yaml --atomic --wait
helm status <rel> -n <ns>; helm ls -A; helm get manifest <rel> -n <ns>
```

## E. 容器运行时 / CRI

```bash
systemctl is-active docker cri-docker cri-docker.socket
crictl --runtime-endpoint /var/run/cri-dockerd.sock info
docker info --format '{{.CgroupDriver}}'
```

## F. 观测（Prometheus / Grafana / ELK）

* **Prom**：
  `kubectl -n monitoring get servicemonitor,podmonitor`
  `curl -s http://<pod>:<port>/metrics | head`
* **Grafana**：导入 JSON、设置数据源（Prom/ES）。
* **ELK**：确保 index pattern（如 `cpemon-*`），并在 Discover 检索；规则需要 **条件+动作** 才会发。

## G. 备份（Velero / MinIO）

```bash
velero backup create <name> --include-namespaces cpemon
velero restore create --from-backup <name>
mc alias set minio http://<minio> <ak> <sk>
kubectl -n cpemon create cronjob db-backup --schedule "0 2 * * *" -- \
  sh -c 'mysqldump ... | gzip | mc cp - minio/mysql-backup/$(date +%F).sql.gz'
```

## H. Linux & 网络（必熟）

```bash
hostnamectl; timedatectl
ip a; ip r; ss -lntp; ping|curl|dig
journalctl -u <svc> -e --no-pager
iptables -t nat -L -n -v
tcpdump -ni any host <ip> or port <p>
```

## I. Git/GitHub（最小闭环）

```bash
ssh-keygen -t ed25519 -C "you@example.com"; ssh -T git@github.com
git add -A; git commit -m "..."; git push
git tag -a day1-done -m "..." && git push origin day1-done
```

## J. 安全与配置

* **Secrets**：`kubectl -n <ns> create secret generic x --from-literal=...`
* **BasicAuth**（Ingress NGINX）：`auth-type=basic`（或 NGINX `auth_basic`），配合 `whitelist-source-range`。
* **签名/HMAC**：服务端校验 `X-Signature`，避免伪造 webhook。

---

# 三、把“重复问点”固化为 3 张小抄（建议入库）

1. `docs/cheatsheets/k8s-triage.md`

   * “五步排障 + 常见错误含义（404/502/504、no endpoints、ImagePullBackOff、CrashLoopBackOff、TLS bad certificate）”
2. `docs/cheatsheets/ingress-notes.md`

   * DaemonSet vs Deployment 对比表、常用注解、IngressClass、与 MetalLB 的关系、典型 YAML 模板
3. `docs/cheatsheets/helm-notes.md`

   * 常用命令、所有权冲突清理清单、`values.yaml` 模板、`--atomic --wait` 的场景

如果你愿意，我可以**把上面三张小抄直接整理成文件内容**发你，你一键粘贴进仓库（不需要你再组织语言）。要不要我现在就给？

