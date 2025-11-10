太好了！我把你 Day-1 实际做过的每一步，**精确映射到老师讲义里的“小标题/段落关键词”**。你只要在对应 PDF 里用 `Ctrl+F` 搜这些小标题或关键词，就能**直达定位**，复习更快更准。

---

# Day-1 复习定位清单（按你今天的步骤顺序）

## 0) Kubernetes 资源清单 & 命名空间基础（给后面所有 YAML 打底）

* **定位**：**《Kubernetes资源对象和Pod资源》** → 小节 “**1.2 资源清单格式 / YAML 格式说明**”（关键词：`1.2 资源清单格式`、`YAML`、`apiVersion/kind/metadata/spec/status`）。
* **用途对应**：创建 `namespaces.yaml`、`pdb/*.yaml` 时理解字段结构、标签/选择器写法。

---

## 1) 节点调度与角色：给 Worker 打标签、Master 加/去污点

* **定位**：**《kubernetes调度机制》**

  * 小节 “**nodeSelector 示例**”（关键词：`nodeSelector`）。
  * 小节 “**Pod 亲和/反亲和（硬/软）**”（关键词：`podAffinity`、`preferredDuringScheduling`）。
  * 小节 “**Taints/Tolerations 与 驱逐/疏散**”（关键词：`taint`、`NoSchedule/NoExecute`、`drain/cordon`）。
* **用途对应**：

  * 给 `k8s-worker1` 打 `ingress-worker=true`；
  * 控制面是否可调度；
  * 以后用亲和/反亲和固定副本分布。

---

## 2) CNI 与 Calico 网段（确认 Pod 网段、Calico 安装）

* **定位**：**《Kubernetes网络插件》**

  * 小节 “**CNI 概述**”（关键词：`CNI`、`Container Network Interface`）。
  * 小节 “**Calico 安装&配置 / IPPool**”（关键词：`Calico`、`IPPools`、`IPv4`）。
* **用途对应**：核对 `PodCIDR` 与 Calico `IPPool` 是否一致，排查网络异常必读。

---

## 3) Service 与集群内解析（为 Ingress 提供后端 Service）

* **定位**：**《Kubernetes服务发现和名称解析》**

  * 小节 “**Service 类型：ClusterIP / NodePort / LoadBalancer**”（关键词：`Service 类型`、`LoadBalancer`）。
  * 小节 “**EndpointSlice**”（关键词：`EndpointSlice`、`discovery.k8s.io/v1`）。
* **用途对应**：

  * 你把 echo 程序做成 `Deployment + Service`；
  * Ingress 通过 Service 发现后端；
  * `kubectl get endpoints/endpointslice` 的意义。

---

## 4) Ingress / NGINX Ingress Controller（从 DaemonSet→Deployment+LB 的切换）

* **定位**：**《Kubernetes流量调度 Ingress》**

  * 小节 “**Ingress 概念与工作方式**”（关键词：`Ingress 基本结构`、`后端`、`路由`）。
  * 小节 “**Ingress 控制器类型与安装（含 YAML/Helm 示例）**”（关键词：`nginx-ingress`、`Helm`、`部署模式`）。
  * 小节 “**通过 Service(type=LoadBalancer) 暴露 Ingress**”（关键词：`LoadBalancer`、`external IP`）。
  * 小节 “**常用注解 / 路径改写**”（关键词：`rewrite-target`、`annotations`）。
* **用途对应**：

  * 你选择 **Deployment + Service(type=LoadBalancer)**（配合 MetalLB 分配 `10.0.0.200`）；
  * `IngressClass=nginx`、`/echo` 路由与改写注解。

---

## 5) MetalLB（让本地集群拥有公网云那样的 LB IP）

* **定位**：**《Kubernetes包管理器 Helm》** 里列出的 **MetalLB CRD 资源**（关键词：`metallb.io/v1beta1/IPAddressPool`、`L2Advertisement`）。
* **用途对应**：

  * 你创建 `IPAddressPool`（`10.0.0.200-210`）与 `L2Advertisement` 后，`ingress-nginx-controller` 得到 `EXTERNAL-IP`。
    -（讲义未单章讲 MetalLB，但 **CRD 名称**与**资源类型**在这页能对应核对。）

---

## 6) Helm（repo、安装、升级、值覆盖、回滚）

* **定位**：**《Kubernetes包管理器 Helm》**

  * 小节 “**添加/更新仓库**”（关键词：`helm repo add`、`helm repo update`）。
  * 小节 “**安装/升级一体化**”（关键词：`helm upgrade --install`、`--atomic --wait`）。
  * 小节 “**通过 -f/--set 覆盖 values**”（关键词：`values.yaml`、`--set`）。
  * 小节 “**状态/回滚**”（关键词：`helm status`、`helm rollback`）。
  * 小节 “**Helm v3 架构（无 Tiller，直接 kubeconfig 访问**）”（关键词：`Helm 3`、`Tiller 移除`）。
* **用途对应**：

  * 你用 Helm 安装了 **ingress-nginx** 与 **metallb**，并通过 `-f` 定制参数。

---

## 7) PDB（PodDisruptionBudget，保障最少可用副本）

* **定位**：

  * **API 资源总览页**能看到 **`policy/v1 PodDisruptionBudget`**（关键词：`poddisruptionbudgets`）。
  * **Helm 文档页**里也出现 `policy/v1/PodDisruptionBudget`（用于 chart 里声明 PDB）。
* **用途对应**：

  * 你为 `cpemon-api`、`acs-ingest` 预先创建 PDB（`minAvailable: 1`），为 Day-3 起应用时的**滚动/驱逐**兜底。

---

## 8) kubeadm join（校验 worker 是否在集群 & 复用 join）

* **定位**：**《Kubernetes集群维护管理》** → 小节 “**kubeadm token create --print-join-command**”。
* **用途对应**：

  * 你用它确认/复用 join 命令，验证 worker 已在集群。

---

## 9) 准入与安全（为 IngressClass/命名空间安全认知补全）

* **定位**：**《Kubernetes安全机制》**

  * 小节 “**Admission 控制（含 DefaultIngressClass）**”（关键词：`Admission`、`DefaultIngressClass`）。
  * 小节 “**RBAC/ServiceAccount/RoleBinding**”（回想你处理过的 `Role/RoleBinding` 冲突）。
* **用途对应**：

  * 你碰到的 **Helm 所有权元数据冲突** 就与 RBAC/资源归属相关；
  * 了解 **默认 IngressClass** 的准入动作，避免多控制器时的选择混乱。

---

# 如何高效复习（建议顺序与方法）

1. **先 20–30 分钟**读：Ingress（概念→控制器→部署），把**从 DaemonSet 到 Deployment+LB** 的取舍搞清楚。对应上面第 4 点的 4 个定位。
2. **再 15 分钟**读：Service 类型 & EndpointSlice，理解 Ingress 后端绑定与探测。
3. **再 15 分钟**过一遍 Helm 的 repo / 安装 / 升级 / values 覆盖（你今天大量使用）。
4. **10 分钟**扫：调度（nodeSelector / taint / 亲和）。把今天打标签、控制面可调度的原理吃透。
5. **10 分钟**看：CNI/Calico 安装与 IPPool，确保能解释 Pod 网段与 MetalLB 的关系。
6. **最后 10 分钟**：看 PDB 的 API 位置 + kubeadm join + Admission/RBAC 概念回顾。

> 复习时对照你仓库里的 `k8s/ingress-nginx/values.yaml`、`k8s/samples/echo/*`、`k8s/pdb/*.yaml` 看一眼——“**讲义段落 → 你今天的 YAML**”，印象会非常牢。
